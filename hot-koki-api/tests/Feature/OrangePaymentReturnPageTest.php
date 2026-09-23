<?php

namespace Tests\Feature;

use Tests\TestCase;

class OrangePaymentReturnPageTest extends TestCase
{
    public function test_page_retour_orange_ne_promet_pas_un_succes_avant_verification(): void
    {
        $this->get('/paiements/orange/retour')
            ->assertOk()
            ->assertSee('Demande transmise')
            ->assertSee('statut final auprès d’Orange Money');
    }

    public function test_page_annulation_orange_invite_a_revenir_dans_application(): void
    {
        $this->get('/paiements/orange/annulation')
            ->assertOk()
            ->assertSee('Paiement annulé')
            ->assertSee('Aucun succès de paiement n’a été confirmé');
    }
}
