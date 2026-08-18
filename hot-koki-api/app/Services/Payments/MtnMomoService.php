<?php

namespace App\Services\Payments;

use App\Models\Paiement;
use Illuminate\Http\Client\PendingRequest;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use RuntimeException;

class MtnMomoService
{
    public function initier(Paiement $paiement): void
    {
        $this->verifierConfiguration();

        if ($paiement->statut !== Paiement::STATUT_INITIE) {
            return;
        }

        $callbackToken = Str::random(64);
        $callbackUrl = rtrim((string) config('services.mtn_momo.callback_base_url'), '/')
            .'/api/webhooks/mtn-momo/'.$callbackToken;

        $paiement->update(['callback_hash' => hash('sha256', $callbackToken)]);

        $response = $this->requeteAutorisee()
            ->withHeaders([
                'X-Reference-Id' => $paiement->reference_interne,
                'X-Target-Environment' => config('services.mtn_momo.target_environment'),
                'X-Callback-Url' => $callbackUrl,
            ])
            ->post('/collection/v1_0/requesttopay', [
                'amount' => (string) $paiement->montant,
                'currency' => config('services.mtn_momo.currency'),
                'externalId' => (string) $paiement->commande_id,
                'payer' => [
                    'partyIdType' => 'MSISDN',
                    'partyId' => $paiement->telephone,
                ],
                'payerMessage' => 'Paiement commande Hot Koki',
                'payeeNote' => 'Commande '.$paiement->commande_id,
            ]);

        if ($response->status() === 409) {
            // Le même X-Reference-Id a déjà pu être accepté avant une coupure
            // locale. La lecture du statut permet de reprendre sans double débit.
            $paiement->update([
                'statut' => Paiement::STATUT_EN_ATTENTE,
                'initie_le' => $paiement->initie_le ?? now(),
                'prochaine_verification_le' => now()->addSeconds(5),
            ]);

            return;
        }

        if ($response->status() !== 202) {
            $paiement->terminer(
                Paiement::STATUT_ECHOUE,
                'MTN_HTTP_'.$response->status(),
                'MTN MoMo a refusé l’initiation du paiement.',
            );

            throw new RuntimeException('MTN MoMo a refusé l’initiation du paiement.');
        }

        $paiement->update([
            'statut' => Paiement::STATUT_EN_ATTENTE,
            'initie_le' => now(),
            'prochaine_verification_le' => now()->addSeconds(5),
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

        $response = $this->requeteAutorisee()
            ->withHeader('X-Target-Environment', config('services.mtn_momo.target_environment'))
            ->get('/collection/v1_0/requesttopay/'.$paiement->reference_interne);

        if (! $response->successful()) {
            $paiement->update([
                'prochaine_verification_le' => now()->addSeconds(
                    in_array($response->status(), [404, 429], true) || $response->serverError() ? 30 : 60
                ),
            ]);

            throw new RuntimeException(
                'Impossible de vérifier le statut MTN MoMo (HTTP '.$response->status().').'
            );
        }

        $paiement->increment('tentatives_statut');

        $donnees = $response->json();
        $statutMtn = strtoupper((string) ($donnees['status'] ?? ''));
        $donneesSures = array_filter([
            'status' => $statutMtn,
            'reason' => $donnees['reason'] ?? null,
        ], fn ($valeur) => $valeur !== null);

        if ($statutMtn === 'SUCCESSFUL') {
            $paiement->confirmerReussite($donnees['financialTransactionId'] ?? null, $donneesSures);
        } elseif (in_array($statutMtn, ['FAILED', 'REJECTED'], true)) {
            $paiement->terminer(Paiement::STATUT_ECHOUE, $statutMtn, 'Le paiement MTN MoMo a échoué.', $donneesSures);
        } elseif ($statutMtn === 'EXPIRED') {
            $paiement->terminer(Paiement::STATUT_EXPIRE, $statutMtn, 'Le paiement MTN MoMo a expiré.', $donneesSures);
        } else {
            $delai = min(300, 5 * (2 ** min($paiement->tentatives_statut, 6)));
            $paiement->update(['prochaine_verification_le' => now()->addSeconds($delai)]);
        }

        return $paiement->fresh();
    }

    private function requeteAutorisee(): PendingRequest
    {
        return Http::baseUrl(config('services.mtn_momo.base_url'))
            ->acceptJson()
            ->asJson()
            ->timeout(15)
            ->withToken($this->token())
            ->withHeader('Ocp-Apim-Subscription-Key', config('services.mtn_momo.subscription_key'));
    }

    private function token(): string
    {
        $empreinte = hash('sha256', implode('|', [
            config('services.mtn_momo.target_environment'),
            config('services.mtn_momo.api_user'),
            config('services.mtn_momo.api_key'),
            config('services.mtn_momo.subscription_key'),
        ]));
        $cacheKey = 'mtn_momo:collection:access_token:'.$empreinte;

        if ($token = Cache::get($cacheKey)) {
            return $token;
        }

        $response = Http::baseUrl(config('services.mtn_momo.base_url'))
            ->withBasicAuth(config('services.mtn_momo.api_user'), config('services.mtn_momo.api_key'))
            ->withHeader('Ocp-Apim-Subscription-Key', config('services.mtn_momo.subscription_key'))
            ->timeout(15)
            ->post('/collection/token/');

        if (! $response->successful() || ! $response->json('access_token')) {
            throw new RuntimeException('Impossible d’obtenir un jeton MTN MoMo (HTTP '.$response->status().').');
        }

        $token = (string) $response->json('access_token');
        $duree = max(60, ((int) $response->json('expires_in', 3600)) - 60);
        Cache::put($cacheKey, $token, now()->addSeconds($duree));

        return $token;
    }

    /** Teste les identifiants sans exposer ni journaliser le jeton obtenu. */
    public function testerConfiguration(): void
    {
        $this->verifierConfiguration();

        if (config('services.mtn_momo.target_environment') === 'sandbox') {
            $response = Http::baseUrl(config('services.mtn_momo.base_url'))
                ->acceptJson()
                ->withHeader('Ocp-Apim-Subscription-Key', config('services.mtn_momo.subscription_key'))
                ->timeout(15)
                ->get('/v1_0/apiuser/'.rawurlencode((string) config('services.mtn_momo.api_user')));

            if (! $response->successful()) {
                throw new RuntimeException('Impossible de vérifier l’API User MTN (HTTP '.$response->status().').');
            }

            $hoteEnregistre = strtolower(rtrim((string) $response->json('providerCallbackHost'), '.'));
            $hoteConfigure = strtolower(rtrim((string) parse_url(
                config('services.mtn_momo.callback_base_url'),
                PHP_URL_HOST,
            ), '.'));

            if ($hoteEnregistre && $hoteEnregistre !== $hoteConfigure) {
                throw new RuntimeException(
                    "Le domaine du callback ({$hoteConfigure}) ne correspond pas au providerCallbackHost MTN ({$hoteEnregistre})."
                );
            }
        }

        $this->token();
    }

    private function verifierConfiguration(): void
    {
        foreach (['subscription_key', 'api_user', 'api_key', 'callback_base_url'] as $cle) {
            if (! config('services.mtn_momo.'.$cle)) {
                throw new RuntimeException('Configuration MTN MoMo incomplète : '.$cle.'.');
            }
        }

        $callback = (string) config('services.mtn_momo.callback_base_url');
        if (! str_starts_with($callback, 'https://') || ! parse_url($callback, PHP_URL_HOST)) {
            throw new RuntimeException('Le callback MTN MoMo doit être une URL HTTPS publique valide.');
        }
    }
}
