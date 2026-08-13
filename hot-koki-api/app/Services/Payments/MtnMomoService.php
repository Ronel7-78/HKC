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

        $response = $this->requeteAutorisee()
            ->withHeader('X-Target-Environment', config('services.mtn_momo.target_environment'))
            ->get('/collection/v1_0/requesttopay/'.$paiement->reference_interne);

        $paiement->increment('tentatives_statut');

        if (! $response->successful()) {
            throw new RuntimeException('Impossible de vérifier le statut MTN MoMo.');
        }

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
        return Cache::remember('mtn_momo:collection:access_token', now()->addMinutes(50), function () {
            $response = Http::baseUrl(config('services.mtn_momo.base_url'))
                ->withBasicAuth(config('services.mtn_momo.api_user'), config('services.mtn_momo.api_key'))
                ->withHeader('Ocp-Apim-Subscription-Key', config('services.mtn_momo.subscription_key'))
                ->post('/collection/token/');

            if (! $response->successful() || ! $response->json('access_token')) {
                throw new RuntimeException('Impossible d’obtenir un jeton MTN MoMo.');
            }

            return $response->json('access_token');
        });
    }

    private function verifierConfiguration(): void
    {
        foreach (['subscription_key', 'api_user', 'api_key', 'callback_base_url'] as $cle) {
            if (! config('services.mtn_momo.'.$cle)) {
                throw new RuntimeException('Configuration MTN MoMo incomplète : '.$cle.'.');
            }
        }
    }
}
