<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class InvalidBusinessProfileSessionTest extends TestCase
{
    use RefreshDatabase;

    public function test_vendeur_sans_profil_ne_peut_pas_ouvrir_une_nouvelle_session(): void
    {
        User::factory()->create([
            'role' => 'vendeur',
            'email' => 'vendeur-incomplet@example.com',
            'password' => 'mot-de-passe',
        ]);

        $this->postJson('/api/login', [
            'email' => 'vendeur-incomplet@example.com',
            'password' => 'mot-de-passe',
            'conditions_acceptees' => true,
        ])->assertStatus(409)
            ->assertJsonPath('code', 'PROFIL_METIER_INTROUVABLE');
    }

    public function test_session_existante_est_revoquee_si_le_profil_vendeur_disparait(): void
    {
        $user = User::factory()->create(['role' => 'vendeur']);
        $token = $user->createToken('test')->plainTextToken;

        $this->withToken($token)
            ->getJson('/api/me')
            ->assertStatus(409)
            ->assertJsonPath('code', 'PROFIL_METIER_INTROUVABLE');

        $this->assertDatabaseCount('personal_access_tokens', 0);
    }
}
