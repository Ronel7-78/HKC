<?php

namespace App\Jobs;

use App\Models\Paiement;
use App\Services\Payments\OrangeMoneyService;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use RuntimeException;

class VerifierPaiementOrange implements ShouldQueue
{
    use Queueable;

    public int $tries = 3;

    public array $backoff = [5, 30, 120];

    public function __construct(public int $paiementId) {}

    public function handle(OrangeMoneyService $orangeMoney): void
    {
        $paiement = Paiement::find($this->paiementId);
        if ($paiement && $paiement->fournisseur === Paiement::FOURNISSEUR_ORANGE_MONEY
            && in_array($paiement->statut, Paiement::STATUTS_ACTIFS, true)) {
            try {
                $orangeMoney->synchroniser($paiement);
            } catch (RuntimeException) {
                // La prochaine synchronisation reprendra après une panne Orange.
            }
        }
    }
}
