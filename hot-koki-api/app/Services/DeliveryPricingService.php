<?php

namespace App\Services;

final class DeliveryPricingService
{
    public function feeForExpress(bool $express): int
    {
        return $express ? (int) config('delivery.flat_fee_xaf', 500) : 0;
    }

    public function displayedDistance(float $distanceKm): float
    {
        return round(max(0, $distanceKm), 3);
    }
}
