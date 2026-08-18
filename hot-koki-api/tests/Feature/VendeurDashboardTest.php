<?php

namespace Tests\Feature;

use App\Models\Avis;
use App\Models\Client;
use App\Models\Commande;
use App\Models\User;
use App\Models\Vendeur;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class VendeurDashboardTest extends TestCase
{
    use RefreshDatabase;

    public function test_vendeur_consulte_ses_statistiques_ses_avis_et_son_profil(): void
    {
        $vendeurUser = User::factory()->create(['role' => 'vendeur']);
        $vendeur = Vendeur::create([
            'user_id' => $vendeurUser->id,
            'nom_boutique' => 'Chez Koki',
            'statut_dispo' => 'disponible',
            'note_moyenne' => 5,
        ]);
        $clientUser = User::factory()->create(['role' => 'client']);
        $client = Client::create(['user_id' => $clientUser->id, 'nom' => 'Client']);
        $commande = Commande::create([
            'client_id' => $client->id,
            'vendeur_id' => $vendeur->id,
            'statut' => Commande::STATUT_LIVREE,
            'adresse_livraison' => 'Bertoua',
            'latitude_client' => 4.5,
            'longitude_client' => 13.6,
            'sous_total' => 1000,
            'frais_livraison' => 300,
            'total' => 1300,
        ]);
        Avis::create([
            'commande_id' => $commande->id,
            'client_id' => $client->id,
            'vendeur_id' => $vendeur->id,
            'note' => 5,
            'commentaire' => 'Excellent.',
        ]);
        Sanctum::actingAs($vendeurUser);

        $this->getJson('/api/vendeur/dashboard')
            ->assertOk()
            ->assertJsonPath('statistiques.commandes_du_jour', 1)
            ->assertJsonPath('statistiques.nombre_avis', 1)
            ->assertJsonCount(1, 'avis_recents');

        $this->getJson('/api/vendeur/avis')
            ->assertOk()
            ->assertJsonCount(1, 'data');

        $this->getJson('/api/vendeur/profile')
            ->assertOk()
            ->assertJsonPath('vendeur.id', $vendeur->id)
            ->assertJsonPath('user.id', $vendeurUser->id);
    }
}
