<?php

namespace App\Services\Payments;

use App\Models\Paiement;
use RuntimeException;

class OrangeMoneyService
{
    public function initier(Paiement $paiement): void
    {
        $this->assertReady();

        throw new RuntimeException('L’intégration transactionnelle Orange Money doit être finalisée avec les accès marchands officiels.');
    }

    public function synchroniser(Paiement $paiement): Paiement
    {
        $this->assertReady();

        throw new RuntimeException('La synchronisation Orange Money n’est pas encore activée.');
    }

    private function assertReady(): void
    {
        if (! config('services.orange_money.enabled')) {
            throw new RuntimeException('Orange Money sera disponible prochainement.');
        }

        foreach (['base_url', 'merchant_key', 'merchant_secret', 'callback_base_url'] as $key) {
            if (! config('services.orange_money.'.$key)) {
                throw new RuntimeException('Configuration Orange Money incomplète : '.$key.'.');
            }
        }
    }
}
