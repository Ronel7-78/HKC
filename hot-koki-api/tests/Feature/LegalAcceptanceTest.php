<?php

namespace Tests\Feature;

use App\Models\Client;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class LegalAcceptanceTest extends TestCase
{
    use RefreshDatabase;

    public function test_inscription_est_bloquee_sans_acceptation(): void
    {
        $this->postJson('/api/register', [
            'name' => 'Client légal',
            'email' => 'legal@example.com',
            'telephone' => '690000010',
            'password' => 'password',
            'password_confirmation' => 'password',
            'adresse_texte' => 'Bertoua',
            'latitude' => 4.57,
            'longitude' => 13.68,
            'conditions_acceptees' => false,
        ])->assertUnprocessable()
            ->assertJsonValidationErrors('conditions_acceptees');
    }

    public function test_connexion_enregistre_la_version_acceptee(): void
    {
        $user = User::factory()->create([
            'role' => 'client',
            'email' => 'connexion@example.com',
            'password' => 'password',
        ]);
        Client::create(['user_id' => $user->id, 'nom' => 'Client']);

        $this->postJson('/api/login', [
            'email' => 'connexion@example.com',
            'password' => 'password',
            'conditions_acceptees' => true,
        ])->assertOk();

        $user->refresh();
        $this->assertNotNull($user->conditions_acceptees_le);
        $this->assertSame(config('legal.version'), $user->conditions_version);
    }
}
