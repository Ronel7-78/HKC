<?php

namespace App\Jobs;

use App\Models\Paiement;
use App\Services\Payments\MtnMomoService;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

class VerifierPaiementMtn implements ShouldQueue
{
    use Queueable;

    public int $tries = 3;

    public array $backoff = [5, 30, 120];

    public function __construct(public int $paiementId) {}

    public function handle(MtnMomoService $mtnMomo): void
    {
        $paiement = Paiement::find($this->paiementId);

        if ($paiement && in_array($paiement->statut, Paiement::STATUTS_ACTIFS, true)) {
            $mtnMomo->synchroniser($paiement);
        }
    }
}
