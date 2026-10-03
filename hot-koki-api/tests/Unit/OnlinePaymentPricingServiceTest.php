<?php

namespace Tests\Unit;

use App\Services\OnlinePaymentPricingService;
use Tests\TestCase;

class OnlinePaymentPricingServiceTest extends TestCase
{
    public function test_le_plus_petit_total_protege_entierement_la_marge(): void
    {
        config([
            'services.campay.collection_rate' => 0.02,
            'services.campay.withdrawal_rate' => 0.01,
        ]);

        $tarification = app(OnlinePaymentPricingService::class)->totals(500, 0);

        $this->assertSame(500, $tarification['montant_commercial']);
        $this->assertSame(16, $tarification['frais_paiement']);
        $this->assertSame(516, $tarification['total']);
        $this->assertGreaterThanOrEqual(500, 516 * 0.98 * 0.99);
        $this->assertLessThan(500, 515 * 0.98 * 0.99);
    }
}
