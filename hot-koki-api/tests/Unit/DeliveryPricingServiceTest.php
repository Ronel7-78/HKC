<?php

namespace Tests\Unit;

use App\Services\DeliveryPricingService;
use Tests\TestCase;

class DeliveryPricingServiceTest extends TestCase
{
    public function test_livraison_est_gratuite_strictement_en_dessous_de_trois_kilometres(): void
    {
        config(['delivery.free_radius_km' => 3, 'delivery.flat_fee_xaf' => 500]);
        $service = new DeliveryPricingService;

        $this->assertSame(0, $service->feeForDistance(0));
        $this->assertSame(0, $service->feeForDistance(2.999));
    }

    public function test_forfait_de_cinq_cents_sapplique_des_trois_kilometres(): void
    {
        config(['delivery.free_radius_km' => 3, 'delivery.flat_fee_xaf' => 500]);
        $service = new DeliveryPricingService;

        $this->assertSame(500, $service->feeForDistance(3.000));
        $this->assertSame(500, $service->feeForDistance(25));
    }
}
