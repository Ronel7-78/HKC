<?php

namespace Tests\Feature;

use App\Models\Client;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ClientProfileTest extends TestCase
{
    use RefreshDatabase;

    public function test_client_consulte_et_modifie_son_compte_complet(): void
    {
        $user = User::factory()->create([
            'role' => 'client',
            'password' => Hash::make('ancien-secret'),
        ]);
        Client::create([
            'user_id' => $user->id,
            'nom' => 'Ancien nom',
            'adresse_texte' => 'Ancienne adresse',
            'latitude' => 4.5,
            'longitude' => 13.6,
        ]);
        Sanctum::actingAs($user);

        $this->getJson('/api/client/profile')
            ->assertOk()
            ->assertJsonPath('user.id', $user->id)
            ->assertJsonPath('client.adresse_texte', 'Ancienne adresse');

        $this->putJson('/api/client/profile', [
            'name' => 'Nouveau nom',
            'nom' => 'Nouveau nom',
            'email' => 'nouveau@example.com',
            'telephone' => '237699999999',
            'adresse_texte' => 'Nouvelle adresse',
            'latitude' => 4.6,
            'longitude' => 13.7,
            'current_password' => 'ancien-secret',
            'password' => 'nouveau-secret',
            'password_confirmation' => 'nouveau-secret',
        ])->assertOk()
            ->assertJsonPath('user.name', 'Nouveau nom')
            ->assertJsonPath('client.adresse_texte', 'Nouvelle adresse');

        $this->assertTrue(Hash::check('nouveau-secret', $user->fresh()->password));
    }
}
