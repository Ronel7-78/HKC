<?php

namespace App\Services\Payments;

use App\Models\Paiement;
use Illuminate\Http\Client\PendingRequest;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use RuntimeException;

class CamPayService
{
    public function initier(Paiement $paiement): void
    {
        $this->verifierConfiguration();

        if ($paiement->statut !== Paiement::STATUT_INITIE) {
            return;
        }

        $response = $this->requeteAutorisee()->post('/api/collect/', [
            'amount' => (string) $this->montantOperateur($paiement),
            'currency' => config('services.campay.currency'),
            'from' => $paiement->telephone,
            'description' => 'Commande Hot Koki '.$paiement->commande?->public_id,
            'external_reference' => $paiement->reference_interne,
        ]);

        $reference = $response->json('reference');
        if (! $response->successful() || ! is_string($reference) || $reference === '') {
            $details = $this->detailsSurs($response->json());
            Log::warning('CamPay a refusé une initiation de paiement', [
                'paiement_id' => $paiement->id,
                'http_status' => $response->status(),
                'details' => $details,
            ]);
            $paiement->terminer(
                Paiement::STATUT_ECHOUE,
                'CAMPAY_HTTP_'.$response->status(),
                'CamPay a refusé l’initiation du paiement.',
                $details,
            );
            throw new RuntimeException('CamPay a refusé l’initiation du paiement.');
        }

        $paiement->update([
            'reference_operateur' => $reference,
            'statut' => Paiement::STATUT_EN_ATTENTE,
            'initie_le' => now(),
            'prochaine_verification_le' => now()->addSeconds(8),
            'donnees_operateur' => array_filter([
                'reference' => $reference,
                'operator' => $response->json('operator'),
                'ussd_code' => $response->json('ussd_code'),
                'status' => 'PENDING',
            ], fn (mixed $value): bool => $value !== null && $value !== ''),
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

        $reference = $paiement->donnees_operateur['reference'] ?? $paiement->reference_operateur;
        if (! is_string($reference) || $reference === '') {
            throw new RuntimeException('Référence CamPay locale incomplète.');
        }

        $response = $this->requeteAutorisee()->get('/api/transaction/'.rawurlencode($reference).'/');
        if (! $response->successful()) {
            $paiement->update(['prochaine_verification_le' => now()->addSeconds(30)]);
            throw new RuntimeException('Impossible de vérifier le statut CamPay (HTTP '.$response->status().').');
        }

        $paiement->increment('tentatives_statut');
        $data = $response->json();
        if (! is_array($data)) {
            throw new RuntimeException('Réponse de vérification CamPay incomplète.');
        }

        $statut = strtoupper((string) ($data['status'] ?? ''));
        $donnees = array_filter([
            ...($paiement->donnees_operateur ?? []),
            'reference' => $reference,
            'status' => $statut,
            'operator' => $data['operator'] ?? null,
            'code' => $data['code'] ?? null,
            'operator_reference' => $data['operator_reference'] ?? null,
        ], fn (mixed $value): bool => $value !== null && $value !== '');

        if ($statut === 'SUCCESSFUL') {
            if (! $this->correspondAuPaiement($paiement, $data)) {
                $paiement->terminer(
                    Paiement::STATUT_ECHOUE,
                    'CAMPAY_VERIFICATION_MISMATCH',
                    'Les informations du paiement reçu ne correspondent pas à la commande.',
                    $donnees,
                );
            } else {
                $referenceOperateur = $data['operator_reference'] ?? $data['code'] ?? $reference;
                $paiement->confirmerReussite((string) $referenceOperateur, $donnees);
            }
        } elseif ($statut === 'FAILED') {
            $paiement->terminer(
                Paiement::STATUT_ECHOUE,
                'CAMPAY_FAILED',
                'Le paiement Mobile Money a échoué.',
                $donnees,
            );
        } else {
            $delai = min(300, 8 * (2 ** min($paiement->tentatives_statut, 5)));
            $paiement->update([
                'donnees_operateur' => $donnees,
                'prochaine_verification_le' => now()->addSeconds($delai),
            ]);
        }

        return $paiement->fresh();
    }

    public function testerConfiguration(): void
    {
        $this->verifierConfiguration();
        $response = $this->requeteAutorisee()->get('/api/balance/');

        if (! $response->successful()) {
            throw new RuntimeException('Les identifiants CamPay ont été refusés (HTTP '.$response->status().').');
        }
    }

    private function requeteAutorisee(): PendingRequest
    {
        return Http::baseUrl(rtrim((string) config('services.campay.base_url'), '/'))
            ->acceptJson()
            ->asJson()
            ->timeout(20)
            ->withHeaders(['Authorization' => 'Token '.$this->jeton()]);
    }

    private function jeton(): string
    {
        return Cache::remember('campay:access-token', now()->addMinutes(50), function (): string {
            $response = Http::baseUrl(rtrim((string) config('services.campay.base_url'), '/'))
                ->acceptJson()
                ->asJson()
                ->timeout(15)
                ->post('/api/token/', [
                    'username' => config('services.campay.username'),
                    'password' => config('services.campay.password'),
                ]);
            $token = $response->json('token');
            if (! $response->successful() || ! is_string($token) || $token === '') {
                throw new RuntimeException('Authentification CamPay refusée.');
            }

            return $token;
        });
    }

    private function correspondAuPaiement(Paiement $paiement, array $data): bool
    {
        return hash_equals($paiement->reference_interne, (string) ($data['external_reference'] ?? ''))
            && strtoupper((string) ($data['currency'] ?? '')) === strtoupper((string) $paiement->devise)
            && abs((float) ($data['amount'] ?? -1) - $this->montantOperateur($paiement)) < 0.01;
    }

    private function montantOperateur(Paiement $paiement): int
    {
        if (strtoupper((string) config('services.campay.environment')) === 'DEV') {
            return max(1, min(25, (int) config('services.campay.demo_amount', 10)));
        }

        return (int) round((float) $paiement->montant);
    }

    private function detailsSurs(mixed $payload): array
    {
        if (! is_array($payload)) {
            return [];
        }

        return collect(['status', 'message', 'detail'])
            ->mapWithKeys(function (string $key) use ($payload): array {
                $value = $payload[$key] ?? null;

                return is_scalar($value) && $value !== ''
                    ? [$key => mb_substr((string) $value, 0, 200)]
                    : [];
            })
            ->all();
    }

    private function verifierConfiguration(): void
    {
        if (! config('services.campay.enabled')) {
            throw new RuntimeException('CamPay est désactivé.');
        }

        foreach (['base_url', 'username', 'password'] as $key) {
            if (blank(config('services.campay.'.$key))) {
                throw new RuntimeException('Configuration CamPay incomplète : '.$key.'.');
            }
        }

        $baseUrl = (string) config('services.campay.base_url');
        if (! str_starts_with($baseUrl, 'https://') || ! parse_url($baseUrl, PHP_URL_HOST)) {
            throw new RuntimeException('L’URL CamPay doit être une URL HTTPS valide.');
        }
    }
}
