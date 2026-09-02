<?php

namespace Tests\Feature;

use App\Models\Paiement;
use Tests\TestCase;

class SecretsSecurityTest extends TestCase
{
    public function test_aucun_secret_configure_n_est_present_dans_les_fichiers_partages(): void
    {
        $this->artisan('security:check-secrets')->assertSuccessful();
    }

    public function test_les_champs_sensibles_d_un_paiement_ne_sont_jamais_serialises(): void
    {
        $paiement = new Paiement([
            'telephone' => '237677000000',
            'callback_hash' => 'hash-secret',
            'donnees_operateur' => ['access_token' => 'token-secret'],
            'reference_interne' => 'reference-interne',
            'reference_operateur' => 'reference-operateur',
        ]);

        $json = $paiement->toArray();

        $this->assertArrayNotHasKey('telephone', $json);
        $this->assertArrayNotHasKey('callback_hash', $json);
        $this->assertArrayNotHasKey('donnees_operateur', $json);
        $this->assertArrayNotHasKey('reference_interne', $json);
        $this->assertArrayNotHasKey('reference_operateur', $json);
    }

    public function test_seule_une_url_https_peut_etre_exposee_pour_un_paiement_orange(): void
    {
        $paiement = new Paiement([
            'fournisseur' => Paiement::FOURNISSEUR_ORANGE_MONEY,
            'statut' => Paiement::STATUT_EN_ATTENTE,
            'donnees_operateur' => ['payment_url' => 'javascript:alert(1)'],
        ]);
        $this->assertNull($paiement->url_paiement);

        $paiement->donnees_operateur = ['payment_url' => 'https://paiement.example.test/session/123'];
        $this->assertSame('https://paiement.example.test/session/123', $paiement->url_paiement);
    }
}
