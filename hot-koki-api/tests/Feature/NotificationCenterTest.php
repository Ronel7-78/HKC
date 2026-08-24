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

    public function test_les_notifications_peuvent_etre_filtrees_sans_nouvelle_table(): void
    {
        $user = User::factory()->create(['role' => 'client']);
        $user->notify(new NotificationMetier([
            'type' => 'commande_creee',
            'titre' => 'Commande créée',
            'message' => 'La commande #42 attend son paiement.',
        ]));
        $user->notify(new NotificationMetier([
            'type' => 'paiement_reussi',
            'titre' => 'Paiement confirmé',
            'message' => 'Le paiement de la commande #41 est confirmé.',
        ]));
        $user->notifications()->where('data->type', 'paiement_reussi')->firstOrFail()->markAsRead();

        Sanctum::actingAs($user);

        $this->getJson('/api/notifications?statut=non_lues&categorie=commandes&recherche=42')
            ->assertOk()
            ->assertJsonCount(1, 'notifications')
            ->assertJsonPath('notifications.0.data.type', 'commande_creee')
            ->assertJsonPath('pagination.total', 1)
            ->assertJsonPath('filtres.categories.0.id', 'commandes')
            ->assertJsonPath('filtres.categories.0.non_lues', 1);

        $this->getJson('/api/notifications?categorie=avis')->assertUnprocessable();
    }

    public function test_la_liste_des_notifications_est_paginatee(): void
    {
        $user = User::factory()->create(['role' => 'admin']);
        foreach (range(1, 3) as $numero) {
            $user->notify(new NotificationMetier([
                'type' => 'test',
                'titre' => "Notification {$numero}",
                'message' => 'Message métier',
            ]));
        }

        Sanctum::actingAs($user);

        $this->getJson('/api/notifications?par_page=2')
            ->assertOk()
            ->assertJsonCount(2, 'notifications')
            ->assertJsonPath('pagination.total', 3)
            ->assertJsonPath('pagination.a_plus', true);
    }
}
