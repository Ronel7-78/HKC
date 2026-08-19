<?php

namespace Tests\Feature;

use App\Models\Annonce;
use App\Models\Avis;
use App\Models\Client;
use App\Models\Commande;
use App\Models\Complement;
use App\Models\Produit;
use App\Models\User;
use App\Models\Vendeur;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AccueilTest extends TestCase
{
    use RefreshDatabase;

    public function test_accueil_retourne_uniquement_annonces_actives_et_avis_reels(): void
    {
        Annonce::query()->delete();
        $produit = Produit::create(['nom' => 'Koki royal', 'prix' => 1000]);
        Annonce::create([
            'type' => 'produit',
            'titre' => 'Koki royal disponible',
            'produit_id' => $produit->id,
            'active' => true,
        ]);
        Annonce::create([
            'type' => 'promotion',
            'titre' => 'Annonce masquée',
            'active' => false,
        ]);

        [$client, $vendeur, $commande] = $this->contexteCommande();
        Avis::create([
            'commande_id' => $commande->id,
            'client_id' => $client->id,
            'vendeur_id' => $vendeur->id,
            'note' => 5,
            'commentaire' => 'Très bon et bien chaud.',
        ]);

        $this->getJson('/api/accueil')
            ->assertOk()
            ->assertJsonCount(1, 'annonces')
            ->assertJsonPath('annonces.0.titre', 'Koki royal disponible')
            ->assertJsonCount(1, 'avis')
            ->assertJsonPath('avis.0.commentaire', 'Très bon et bien chaud.');
    }

    public function test_admin_gere_les_annonces_et_client_recoit_un_vendeur_commandable(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        Sanctum::actingAs($admin);
        $creation = $this->postJson('/api/admin/annonces', [
            'type' => 'promotion',
            'titre' => 'Livraison offerte',
            'description' => 'Aujourd’hui seulement',
            'active' => true,
        ])->assertCreated();
        $annonceId = $creation->json('annonce.id');
        $this->deleteJson('/api/admin/annonces/'.$annonceId)
            ->assertOk()
            ->assertJsonPath('message', 'Annonce supprimée.');
        $this->assertDatabaseMissing('annonces', ['id' => $annonceId]);
        $this->getJson('/api/accueil')->assertJsonMissing(['id' => $annonceId]);

        $clientUser = User::factory()->create(['role' => 'client']);
        Client::create([
            'user_id' => $clientUser->id,
            'nom' => 'Client',
            'latitude' => 4.05,
            'longitude' => 9.70,
        ]);
        $vendeurUser = User::factory()->create(['role' => 'vendeur']);
        $vendeur = Vendeur::create([
            'user_id' => $vendeurUser->id,
            'nom_boutique' => 'Koki Akwa',
            'statut_compte' => 'actif',
            'statut_dispo' => 'disponible',
            'latitude' => 4.051,
            'longitude' => 9.701,
        ]);
        $produit = Produit::create(['nom' => 'Koki', 'prix' => 500]);
        $complement = Complement::create(['nom' => 'Manioc']);
        $produit->complements()->attach($complement);
        $vendeur->produits()->attach($produit, ['statut' => 'disponible']);

        Sanctum::actingAs($clientUser);
        $this->getJson('/api/client/catalogue')
            ->assertOk()
            ->assertJsonPath('produits.0.vendeur_choisi.id', $vendeur->id)
            ->assertJsonPath('produits.0.complements.0.id', $complement->id);
    }

    /** @return array{Client, Vendeur, Commande} */
    private function contexteCommande(): array
    {
        $clientUser = User::factory()->create(['role' => 'client', 'name' => 'Marie Test']);
        $client = Client::create(['user_id' => $clientUser->id, 'nom' => 'Marie']);
        $vendeurUser = User::factory()->create(['role' => 'vendeur']);
        $vendeur = Vendeur::create(['user_id' => $vendeurUser->id, 'nom_boutique' => 'Koki Test']);
        $commande = Commande::create([
            'client_id' => $client->id,
            'vendeur_id' => $vendeur->id,
            'statut' => Commande::STATUT_LIVREE,
            'adresse_livraison' => 'Douala',
            'latitude_client' => 4.05,
            'longitude_client' => 9.70,
            'sous_total' => 1000,
            'frais_livraison' => 300,
            'total' => 1300,
        ]);

        return [$client, $vendeur, $commande];
    }
}
