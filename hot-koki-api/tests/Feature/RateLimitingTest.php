<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\RateLimiter;
use Tests\TestCase;

class RateLimitingTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        RateLimiter::clear('login-minute:'.hash('sha256', 'attaque@hotkoki.test|127.0.0.1'));
        RateLimiter::clear('login-hour:'.hash('sha256', 'attaque@hotkoki.test|127.0.0.1'));
        RateLimiter::clear('email-minute:'.hash('sha256', 'reset@hotkoki.test|127.0.0.1'));
        RateLimiter::clear('email-hour:'.hash('sha256', 'reset@hotkoki.test|127.0.0.1'));
    }

    public function test_connexion_est_bloquee_apres_cinq_tentatives_par_minute(): void
    {
        $payload = [
            'email' => 'attaque@hotkoki.test',
            'password' => 'mot-de-passe-invalide',
            'conditions_acceptees' => true,
        ];

        for ($tentative = 1; $tentative <= 5; $tentative++) {
            $this->postJson('/api/login', $payload)->assertUnauthorized();
        }

        $this->postJson('/api/login', $payload)
            ->assertTooManyRequests()
            ->assertJsonPath('code', 'TROP_DE_REQUETES')
            ->assertJsonStructure(['message', 'code', 'retry_after']);
    }

    public function test_un_seul_email_de_recuperation_peut_etre_demande_par_minute(): void
    {
        $payload = ['email' => 'reset@hotkoki.test'];

        $this->postJson('/api/forgot-password', $payload)->assertAccepted();
        $this->postJson('/api/forgot-password', $payload)
            ->assertTooManyRequests()
            ->assertJsonPath('code', 'TROP_DE_REQUETES');
    }
}
