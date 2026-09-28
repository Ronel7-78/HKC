<?php

namespace App\Jobs;

use App\Models\Paiement;
use App\Services\Payments\FlutterwaveService;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use RuntimeException;

class VerifierPaiementFlutterwave implements ShouldQueue
{
    use Queueable;

    public int $tries = 3;

    public array $backoff = [5, 30, 120];

    public function __construct(public int $paiementId) {}

    public function handle(FlutterwaveService $flutterwave): void
    {
        $paiement = Paiement::find($this->paiementId);

        if ($paiement?->passerelle === Paiement::PASSERELLE_FLUTTERWAVE
            && in_array($paiement->statut, Paiement::STATUTS_ACTIFS, true)) {
            try {
                $flutterwave->synchroniser($paiement);
            } catch (RuntimeException) {
                // Le scheduler reprendra la vérification après l'incident temporaire.
            }
        }
    }
}
