<?php

namespace App\Services\Payments;

use App\Models\Paiement;
use Illuminate\Http\Client\PendingRequest;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use RuntimeException;

class FlutterwaveService
{
    public function initier(Paiement $paiement): void
    {
        $this->verifierConfiguration();

        if ($paiement->statut !== Paiement::STATUT_INITIE) {
            return;
        }

        $paiement->loadMissing('commande.client.user');
        $user = $paiement->commande?->client?->user;
        if (! $user?->email) {
            throw new RuntimeException('Le client doit avoir une adresse e-mail avant le paiement.');
        }

        $response = $this->requeteAutorisee()->post('/charges?type=mobile_money_franco', [
            'amount' => (int) round((float) $paiement->montant),
            'currency' => config('services.flutterwave.currency'),
            'country' => config('services.flutterwave.country'),
            'network' => $this->reseau($paiement),
            'phone_number' => $paiement->telephone,
            'email' => $user->email,
            'fullname' => $user->name,
            'tx_ref' => $paiement->reference_interne,
            'redirect_url' => rtrim((string) config('services.flutterwave.callback_base_url'), '/')
                .'/paiements/flutterwave/retour',
            'meta' => [
                'commande_id' => $paiement->commande?->public_id,
                'paiement_id' => $paiement->public_id,
            ],
        ]);

        $data = $response->json('data');
        if (! $response->successful() || $response->json('status') !== 'success' || ! is_array($data)) {
            $details = $this->detailsSurs($response->json());
            Log::warning('Flutterwave a refusé une initiation de paiement', [
                'paiement_id' => $paiement->id,
                'http_status' => $response->status(),
                'operateur' => $paiement->fournisseur,
                'details' => $details,
            ]);
            $paiement->terminer(
                Paiement::STATUT_ECHOUE,
                'FLW_HTTP_'.$response->status(),
                'Flutterwave a refusé l’initiation du paiement.',
                $details,
            );
            throw new RuntimeException('Flutterwave a refusé l’initiation du paiement.');
        }

        $transactionId = $data['id'] ?? null;
        if (! is_int($transactionId) && ! ctype_digit((string) $transactionId)) {
            throw new RuntimeException('Réponse Flutterwave incomplète : identifiant absent.');
        }

        $statut = strtolower((string) ($data['status'] ?? 'pending'));
        $donnees = array_filter([
            'transaction_id' => (int) $transactionId,
            'flw_ref' => $data['flw_ref'] ?? null,
            'status' => $statut,
            'payment_type' => $data['payment_type'] ?? null,
            'network' => $this->reseau($paiement),
            'payment_url' => $this->urlAutorisation($data),
        ], fn (mixed $value): bool => $value !== null && $value !== '');

        $paiement->update([
            'reference_operateur' => is_scalar($data['flw_ref'] ?? null)
                ? (string) $data['flw_ref']
                : null,
            'statut' => Paiement::STATUT_EN_ATTENTE,
            'initie_le' => now(),
            'prochaine_verification_le' => now()->addSeconds(8),
            'donnees_operateur' => $donnees,
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

        $transactionId = $paiement->donnees_operateur['transaction_id'] ?? null;
        if (! is_int($transactionId) && ! ctype_digit((string) $transactionId)) {
            throw new RuntimeException('Référence Flutterwave locale incomplète.');
        }

        $response = $this->requeteAutorisee()->get('/transactions/'.rawurlencode((string) $transactionId).'/verify');
        if (! $response->successful() || $response->json('status') !== 'success') {
            $paiement->update(['prochaine_verification_le' => now()->addSeconds(30)]);
            throw new RuntimeException('Impossible de vérifier le statut Flutterwave (HTTP '.$response->status().').');
        }

        $paiement->increment('tentatives_statut');
        $data = $response->json('data');
        if (! is_array($data)) {
            throw new RuntimeException('Réponse de vérification Flutterwave incomplète.');
        }

        $statut = strtolower((string) ($data['status'] ?? ''));
        $donnees = array_filter([
            ...($paiement->donnees_operateur ?? []),
            'transaction_id' => (int) $transactionId,
            'flw_ref' => $data['flw_ref'] ?? null,
            'status' => $statut,
            'payment_type' => $data['payment_type'] ?? null,
        ], fn (mixed $value): bool => $value !== null && $value !== '');

        if ($statut === 'successful') {
            if (! $this->correspondAuPaiement($paiement, $data)) {
                $paiement->terminer(
                    Paiement::STATUT_ECHOUE,
                    'FLW_VERIFICATION_MISMATCH',
                    'Les informations du paiement reçu ne correspondent pas à la commande.',
                    $donnees,
                );
            } else {
                $paiement->confirmerReussite((string) ($data['flw_ref'] ?? $transactionId), $donnees);
            }
        } elseif (in_array($statut, ['failed', 'cancelled', 'canceled'], true)) {
            $paiement->terminer(
                Paiement::STATUT_ECHOUE,
                'FLW_'.strtoupper($statut),
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
        $response = $this->requeteAutorisee()->get('/transactions', ['page' => 1]);

        if (! $response->successful()) {
            throw new RuntimeException('Les identifiants Flutterwave ont été refusés (HTTP '.$response->status().').');
        }
    }

    private function requeteAutorisee(): PendingRequest
    {
        return Http::baseUrl(rtrim((string) config('services.flutterwave.base_url'), '/'))
            ->acceptJson()
            ->asJson()
            ->timeout(20)
            ->withToken((string) config('services.flutterwave.secret_key'));
    }

    private function reseau(Paiement $paiement): string
    {
        return match ($paiement->fournisseur) {
            Paiement::FOURNISSEUR_MTN_MOMO => 'MTN',
            Paiement::FOURNISSEUR_ORANGE_MONEY => 'ORANGEMONEY',
            default => throw new RuntimeException('Réseau Mobile Money non pris en charge.'),
        };
    }

    private function correspondAuPaiement(Paiement $paiement, array $data): bool
    {
        return hash_equals($paiement->reference_interne, (string) ($data['tx_ref'] ?? ''))
            && strtoupper((string) ($data['currency'] ?? '')) === strtoupper((string) $paiement->devise)
            && abs((float) ($data['amount'] ?? -1) - (float) $paiement->montant) < 0.01;
    }

    private function urlAutorisation(array $data): ?string
    {
        $candidates = [
            $data['auth_url'] ?? null,
            $data['redirect_url'] ?? null,
            $data['meta']['authorization']['redirect'] ?? null,
        ];

        foreach ($candidates as $candidate) {
            if (! is_string($candidate)) {
                continue;
            }
            $parsed = parse_url($candidate);
            if (($parsed['scheme'] ?? null) === 'https' && ! empty($parsed['host'])) {
                return $candidate;
            }
        }

        return null;
    }

    private function detailsSurs(mixed $payload): array
    {
        if (! is_array($payload)) {
            return [];
        }

        return collect(['status', 'message'])
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
        if (! config('services.flutterwave.enabled')) {
            throw new RuntimeException('Flutterwave est désactivé.');
        }

        foreach (['base_url', 'secret_key', 'webhook_secret', 'callback_base_url'] as $key) {
            if (blank(config('services.flutterwave.'.$key))) {
                throw new RuntimeException('Configuration Flutterwave incomplète : '.$key.'.');
            }
        }

        $callback = (string) config('services.flutterwave.callback_base_url');
        if (! str_starts_with($callback, 'https://') || ! parse_url($callback, PHP_URL_HOST)) {
            throw new RuntimeException('Le callback Flutterwave doit être une URL HTTPS publique valide.');
        }
    }
}
