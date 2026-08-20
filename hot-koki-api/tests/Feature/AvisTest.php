<?php

namespace Tests\Feature;

use App\Models\Client;
use App\Models\Commande;
use App\Models\User;
use App\Models\Vendeur;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AvisTest extends TestCase
{
    use RefreshDatabase;

    public function test_client_note_uniquement_sa_commande_livree(): void
    {
        $user = User::factory()->create(['role' => 'client']);
        $client = Client::create(['user_id' => $user->id, 'nom' => 'Client']);
        $vendeur = Vendeur::create([
            'user_id' => User::factory()->create(['role' => 'vendeur'])->id,
            'nom_boutique' => 'Chez Koki',
        ]);
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
        Sanctum::actingAs($user);

        $this->postJson("/api/commandes/{$commande->public_id}/avis", [
            'note' => 5,
            'commentaire' => 'Très bon.',
        ])->assertOk()->assertJsonPath('avis.note', 5);

        $this->assertEquals(5, $vendeur->fresh()->note_moyenne);
        $this->getJson('/api/client/avis')->assertOk()->assertJsonCount(1);
    }
}
