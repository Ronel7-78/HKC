<?php

namespace Tests\Unit;

use App\Services\DeliveryPricingService;
use Tests\TestCase;

class DeliveryPricingServiceTest extends TestCase
{
    public function test_livraison_standard_est_gratuite(): void
    {
        config(['delivery.flat_fee_xaf' => 500]);
        $service = new DeliveryPricingService;

        $this->assertSame(0, $service->feeForExpress(false));
    }

    public function test_livraison_express_coute_cinq_cents(): void
    {
        config(['delivery.flat_fee_xaf' => 500]);
        $service = new DeliveryPricingService;

        $this->assertSame(500, $service->feeForExpress(true));
    }
}
