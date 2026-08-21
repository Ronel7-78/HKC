<?php

namespace App\Services;

final class DeliveryPricingService
{
    public function feeForDistance(float $distanceKm): int
    {
        return $distanceKm < config('delivery.free_radius_km')
            ? 0
            : config('delivery.flat_fee_xaf');
    }

    public function displayedDistance(float $distanceKm): float
    {
        return round(max(0, $distanceKm), 3);
    }
}
