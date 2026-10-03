<?php

namespace App\Services;

final class OnlinePaymentPricingService
{
    /**
     * Calcule le plus petit montant entier qui protège entièrement le montant
     * commercial après les commissions successives d'encaissement et de retrait.
     *
     * @return array{montant_commercial: int, frais_paiement: int, total: int}
     */
    public function totals(int|float|string $sousTotal, int|float|string $fraisLivraison): array
    {
        $montantCommercial = (int) round((float) $sousTotal + (float) $fraisLivraison);
        $tauxEncaissement = $this->rate('collection_rate', 0.02);
        $tauxRetrait = $this->rate('withdrawal_rate', 0.01);
        $coefficientNet = (1 - $tauxEncaissement) * (1 - $tauxRetrait);

        if ($montantCommercial <= 0 || $coefficientNet <= 0) {
            return [
                'montant_commercial' => max(0, $montantCommercial),
                'frais_paiement' => 0,
                'total' => max(0, $montantCommercial),
            ];
        }

        $total = (int) ceil($montantCommercial / $coefficientNet);

        return [
            'montant_commercial' => $montantCommercial,
            'frais_paiement' => $total - $montantCommercial,
            'total' => $total,
        ];
    }

    private function rate(string $key, float $fallback): float
    {
        return min(0.99, max(0, (float) config("services.campay.{$key}", $fallback)));
    }
}
