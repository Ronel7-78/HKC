<?php

namespace Tests\Feature;

use App\Models\Client;
use App\Models\Commande;
use App\Models\User;
use App\Models\Vendeur;
use App\Notifications\NotificationMetier;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class NotificationCenterTest extends TestCase
{
    use RefreshDatabase;

    public function test_chaque_profil_accede_uniquement_a_ses_notifications_et_peut_les_lire(): void
    {
        foreach (['client', 'vendeur', 'admin'] as $role) {
            $user = User::factory()->create(['role' => $role]);
            $user->notify(new NotificationMetier([
                'type' => 'test',
                'titre' => "Notification {$role}",
                'message' => 'Message métier',
            ]));

            Sanctum::actingAs($user);
            $response = $this->getJson('/api/notifications')
                ->assertOk()
                ->assertJsonPath('non_lues', 1)
                ->assertJsonCount(1, 'notifications');

            $id = $response->json('notifications.0.id');
            $this->patchJson("/api/notifications/{$id}/lire")->assertOk();
            $this->getJson('/api/notifications')->assertJsonPath('non_lues', 0);
        }
    }

    public function test_changement_de_statut_notifie_le_client_concerne(): void
    {
        $clientUser = User::factory()->create(['role' => 'client']);
        $client = Client::create(['user_id' => $clientUser->id, 'nom' => 'Client']);
        $vendeurUser = User::factory()->create(['role' => 'vendeur']);
        $vendeur = Vendeur::create([
            'user_id' => $vendeurUser->id,
            'nom_boutique' => 'Koki chaud',
        ]);
        $commande = Commande::create([
            'client_id' => $client->id,
            'vendeur_id' => $vendeur->id,
            'statut' => Commande::STATUT_RECUE,
            'adresse_livraison' => 'Douala',
            'latitude_client' => 4.05,
            'longitude_client' => 9.70,
            'sous_total' => 1000,
            'frais_livraison' => 300,
            'total' => 1300,
        ]);

        Sanctum::actingAs($vendeurUser);
        $this->patchJson("/api/vendeur/commandes/{$commande->public_id}/statut", [
            'statut' => Commande::STATUT_PREPARATION,
        ])->assertOk();

        $this->assertDatabaseHas('notifications', [
            'notifiable_id' => $clientUser->id,
            'notifiable_type' => User::class,
        ]);
    }
}
