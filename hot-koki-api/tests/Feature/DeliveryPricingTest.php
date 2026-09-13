<?php

namespace Tests\Feature;

use App\Models\Client;
use App\Models\Complement;
use App\Models\Produit;
use App\Models\User;
use App\Models\Vendeur;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class DeliveryPricingTest extends TestCase
{
    use RefreshDatabase;

    public function test_livraison_standard_est_gratuite_independamment_de_la_distance(): void
    {
        [$payload, $vendeur] = $this->context();

        $preview = $this->postJson('/api/commandes/preview', $payload)
            ->assertOk()
            ->assertJsonPath('frais_livraison', 0)
            ->assertJsonPath('livraison_express', false)
            ->assertJsonPath('livraison_gratuite', true)
            ->assertJsonPath('total', 1000);

        $distance = (float) $preview->json('vendeur.distance_km');
        $this->assertGreaterThanOrEqual(3, $distance);

        $creation = $this->postJson('/api/commandes', $payload + ['vendeur_id' => $vendeur->id])
            ->assertCreated()
            ->assertJsonPath('commande.frais_livraison', '0.00')
            ->assertJsonPath('commande.livraison_express', false)
            ->assertJsonPath('commande.distance_km', number_format($distance, 3, '.', ''));

        $this->assertDatabaseHas('commandes', [
            'id' => $creation->json('commande.id'),
            'frais_livraison' => 0,
            'livraison_express' => false,
        ]);
    }

    public function test_livraison_express_ajoute_un_forfait_de_500_fcfa(): void
    {
        [$payload] = $this->context();
        $pointUser = User::factory()->create(['role' => 'vendeur']);
        $pointFixe = Vendeur::create([
            'user_id' => $pointUser->id,
            'nom_boutique' => 'Point express',
            'type_vendeur' => Vendeur::TYPE_POINT_FIXE,
            'accepte_express' => true,
            'latitude' => 4.0600,
            'longitude' => 9.7000,
            'statut_dispo' => 'disponible',
            'statut_compte' => 'actif',
        ]);
        $pointFixe->produits()->attach($payload['items'][0]['produit_id'], ['statut' => 'disponible']);
        $payload['livraison_express'] = true;

        $this->postJson('/api/commandes/preview', $payload)
            ->assertOk()
            ->assertJsonPath('frais_livraison', 500)
            ->assertJsonPath('livraison_express', true)
            ->assertJsonPath('vendeur.id', $pointFixe->id)
            ->assertJsonPath('total', 1500);

        $this->postJson('/api/commandes', $payload)
            ->assertCreated()
            ->assertJsonPath('commande.frais_livraison', '500.00')
            ->assertJsonPath('commande.livraison_express', true)
            ->assertJsonPath('commande.vendeur_id', $pointFixe->id);
    }

    /** @return array{array<string, mixed>, Vendeur} */
    private function context(): array
    {
        $clientUser = User::factory()->create(['role' => 'client']);
        Client::create(['user_id' => $clientUser->id, 'nom' => 'Client']);
        Sanctum::actingAs($clientUser);

        $vendeurUser = User::factory()->create(['role' => 'vendeur']);
        $vendeur = Vendeur::create([
            'user_id' => $vendeurUser->id,
            'nom_boutique' => 'Koki éloigné',
            'latitude' => 4.0500,
            'longitude' => 9.7000,
            'statut_dispo' => 'disponible',
            'statut_compte' => 'actif',
        ]);
        $produit = Produit::create(['nom' => 'Koki', 'prix' => 1000]);
        $complement = Complement::create(['nom' => 'Banane']);
        $produit->complements()->attach($complement);
        $vendeur->produits()->attach($produit, ['statut' => 'disponible']);

        return [[
            'items' => [[
                'produit_id' => $produit->id,
                'quantite' => 1,
                'complements' => [$complement->id],
            ]],
            'adresse_livraison' => 'Bertoua',
            'latitude_client' => 4.0900,
            'longitude_client' => 9.7000,
        ], $vendeur];
    }
}
