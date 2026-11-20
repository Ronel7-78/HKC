<?php

namespace Tests\Feature;

use Tests\TestCase;

class PublicLegalPagesTest extends TestCase
{
    public function test_privacy_policy_is_publicly_available(): void
    {
        $this->get('/confidentialite')
            ->assertOk()
            ->assertSee('Politique de confidentialité')
            ->assertSee('contact.hotkoki@gmail.com');
    }

    public function test_terms_are_publicly_available(): void
    {
        $this->get('/conditions-utilisation')
            ->assertOk()
            ->assertSee('Conditions d’utilisation')
            ->assertSee('contact.hotkoki@gmail.com');
    }
}
