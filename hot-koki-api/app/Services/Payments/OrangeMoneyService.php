<?php

namespace App\Services\Payments;

use App\Models\Paiement;
use Illuminate\Http\Client\PendingRequest;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use RuntimeException;

class OrangeMoneyService
{
    public function initier(Paiement $paiement): void
    {
        $this->verifierConfiguration();

        if ($paiement->statut !== Paiement::STATUT_INITIE) {
            return;
        }

        $orderId = 'HK'.$paiement->id.'-'.substr(str_replace('-', '', $paiement->reference_interne), 0, 16);
        $response = $this->requeteAutorisee()->post($this->endpoint('webpayment'), [
            'merchant_key' => config('services.orange_money.merchant_key'),
            'currency' => config('services.orange_money.currency'),
            'order_id' => $orderId,
            'amount' => (int) round((float) $paiement->montant),
            'return_url' => config('services.orange_money.return_url'),
            'cancel_url' => config('services.orange_money.cancel_url'),
            'notif_url' => rtrim((string) config('services.orange_money.callback_base_url'), '/')
                .'/api/webhooks/orange-money',
            'lang' => config('services.orange_money.language'),
            'reference' => 'Commande Hot Koki #'.$paiement->commande_id,
        ]);

        if (! $response->successful()) {
            throw new RuntimeException('Orange Money a refusé l’initiation (HTTP '.$response->status().').');
        }

        $paymentToken = (string) $response->json('payment_token');
        $paymentUrl = (string) $response->json('payment_url');
        $notifToken = (string) $response->json('notif_token');
        if (! $paymentToken || ! $paymentUrl || ! $notifToken) {
            throw new RuntimeException('Réponse Orange Money incomplète.');
        }

        $paiement->update([
            'statut' => Paiement::STATUT_EN_ATTENTE,
            'callback_hash' => hash('sha256', $notifToken),
            'initie_le' => now(),
            'prochaine_verification_le' => now()->addSeconds(10),
            'donnees_operateur' => [
                'order_id' => $orderId,
                'payment_token' => $paymentToken,
                'payment_url' => $paymentUrl,
                'status' => strtoupper((string) $response->json('status', 'INITIATED')),
            ],
        ]);
    }

    public function synchroniser(Paiement $paiement): Paiement
    {
        $this->verifierConfiguration();

        if (! in_array($paiement->statut, Paiement::STATUTS_ACTIFS, true)) {
            return $paiement;
        }

        if ($paiement->statut === Paiement::STATUT_INITIE) {
            $this->initier($paiement);
            $paiement->refresh();
        }

        $operateur = $paiement->donnees_operateur ?? [];
        if (empty($operateur['order_id']) || empty($operateur['payment_token'])) {
            throw new RuntimeException('Référence Orange Money locale incomplète.');
        }

        $response = $this->requeteAutorisee()->post($this->endpoint('status'), [
            'order_id' => $operateur['order_id'],
            'amount' => (int) round((float) $paiement->montant),
            'pay_token' => $operateur['payment_token'],
        ]);

        if (! $response->successful()) {
            $paiement->update(['prochaine_verification_le' => now()->addSeconds(30)]);
            throw new RuntimeException('Impossible de vérifier le statut Orange Money (HTTP '.$response->status().').');
        }

        $paiement->increment('tentatives_statut');
        $statut = strtoupper((string) $response->json('status'));
        $donneesSures = [
            ...$operateur,
            'status' => $statut,
            'txnid' => $response->json('txnid'),
        ];

        if (in_array($statut, ['SUCCESS', 'SUCCESSFUL'], true)) {
            $paiement->confirmerReussite($response->json('txnid'), $donneesSures);
        } elseif (in_array($statut, ['FAILED', 'FAILURE', 'CANCELLED', 'CANCELED'], true)) {
            $paiement->terminer(Paiement::STATUT_ECHOUE, $statut, 'Le paiement Orange Money a échoué.', $donneesSures);
        } elseif ($statut === 'EXPIRED') {
            $paiement->terminer(Paiement::STATUT_EXPIRE, $statut, 'Le paiement Orange Money a expiré.', $donneesSures);
        } else {
            $delai = min(300, 10 * (2 ** min($paiement->tentatives_statut, 5)));
            $paiement->update([
                'donnees_operateur' => $donneesSures,
                'prochaine_verification_le' => now()->addSeconds($delai),
            ]);
        }

        return $paiement->fresh();
    }

    public function testerConfiguration(): void
    {
        $this->verifierConfiguration();
        $this->token();
    }

    private function requeteAutorisee(): PendingRequest
    {
        return Http::baseUrl(rtrim((string) config('services.orange_money.base_url'), '/'))
            ->acceptJson()
            ->asJson()
            ->timeout(15)
            ->withToken($this->token());
    }

    private function token(): string
    {
        $empreinte = hash('sha256', implode('|', [
            config('services.orange_money.client_id'),
            config('services.orange_money.client_secret'),
            config('services.orange_money.environment'),
        ]));
        $cacheKey = 'orange_money:access_token:'.$empreinte;
        if ($token = Cache::get($cacheKey)) {
            return $token;
        }

        $response = Http::baseUrl(rtrim((string) config('services.orange_money.auth_base_url'), '/'))
            ->withBasicAuth(
                (string) config('services.orange_money.client_id'),
                (string) config('services.orange_money.client_secret'),
            )
            ->asForm()
            ->acceptJson()
            ->timeout(15)
            ->post(config('services.orange_money.token_path'), ['grant_type' => 'client_credentials']);

        if (! $response->successful() || ! $response->json('access_token')) {
            throw new RuntimeException('Impossible d’obtenir un jeton Orange Money (HTTP '.$response->status().').');
        }

        $token = (string) $response->json('access_token');
        Cache::put($cacheKey, $token, now()->addSeconds(max(60, (int) $response->json('expires_in', 3600) - 60)));

        return $token;
    }

    private function endpoint(string $operation): string
    {
        return rtrim((string) config('services.orange_money.webpay_path'), '/')
            .'/'.ltrim((string) config('services.orange_money.'.$operation.'_path'), '/');
    }

    private function verifierConfiguration(): void
    {
        if (! config('services.orange_money.enabled')) {
            throw new RuntimeException('Orange Money est désactivé.');
        }

        foreach (['base_url', 'auth_base_url', 'client_id', 'client_secret', 'merchant_key', 'callback_base_url', 'return_url', 'cancel_url'] as $cle) {
            if (! config('services.orange_money.'.$cle)) {
                throw new RuntimeException('Configuration Orange Money incomplète : '.$cle.'.');
            }
        }

        $callback = (string) config('services.orange_money.callback_base_url');
        if (! str_starts_with($callback, 'https://') || ! parse_url($callback, PHP_URL_HOST)) {
            throw new RuntimeException('Le callback Orange Money doit être une URL HTTPS publique valide.');
        }
    }
}
