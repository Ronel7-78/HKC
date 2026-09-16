<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PushTokenTest extends TestCase
{
    use RefreshDatabase;

    public function test_un_utilisateur_authentifie_peut_enregistrer_et_supprimer_son_appareil(): void
    {
        $user = User::factory()->create(['role' => 'client']);
        Sanctum::actingAs($user);

        $this->postJson('/api/notifications/appareil', [
            'token' => 'fcm-token-test',
            'platform' => 'android',
        ])->assertOk();

        $this->assertDatabaseHas('push_tokens', [
            'user_id' => $user->id,
            'token' => 'fcm-token-test',
            'platform' => 'android',
        ]);

        $this->deleteJson('/api/notifications/appareil', [
            'token' => 'fcm-token-test',
        ])->assertOk();

        $this->assertDatabaseMissing('push_tokens', ['token' => 'fcm-token-test']);
    }

    public function test_un_token_fcm_change_de_proprietaire_lors_dune_nouvelle_connexion(): void
    {
        $premier = User::factory()->create(['role' => 'client']);
        $second = User::factory()->create(['role' => 'vendeur']);

        Sanctum::actingAs($premier);
        $this->postJson('/api/notifications/appareil', [
            'token' => 'meme-telephone',
            'platform' => 'android',
        ])->assertOk();

        Sanctum::actingAs($second);
        $this->postJson('/api/notifications/appareil', [
            'token' => 'meme-telephone',
            'platform' => 'android',
        ])->assertOk();

        $this->assertDatabaseCount('push_tokens', 1);
        $this->assertDatabaseHas('push_tokens', [
            'user_id' => $second->id,
            'token' => 'meme-telephone',
        ]);
    }
}
