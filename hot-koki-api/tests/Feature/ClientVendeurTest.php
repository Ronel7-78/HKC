<?php

namespace Tests\Feature;

use App\Models\Client;
use App\Models\Produit;
use App\Models\User;
use App\Models\Vendeur;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ClientVendeurTest extends TestCase
{
    use RefreshDatabase;

    public function test_client_localise_consulte_les_vendeurs_disponibles_proches(): void
    {
        $clientUser = User::factory()->create(['role' => 'client']);
        Client::create(['user_id' => $clientUser->id, 'latitude' => 4.5763, 'longitude' => 13.6845]);
        $vendeurUser = User::factory()->create(['role' => 'vendeur']);
        $vendeur = Vendeur::create([
            'user_id' => $vendeurUser->id,
            'nom_boutique' => 'Koki Mokolo',
            'latitude' => 4.5764,
            'longitude' => 13.6846,
            'statut_compte' => 'actif',
            'statut_dispo' => 'disponible',
        ]);
        $produit = Produit::create(['nom' => 'Koki', 'prix' => 500]);
        $vendeur->produits()->attach($produit, ['statut' => 'disponible']);
        Sanctum::actingAs($clientUser);

        $this->getJson('/api/client/vendeurs?q=Koki')
            ->assertOk()
            ->assertJsonCount(1, 'vendeurs')
            ->assertJsonPath('vendeurs.0.nom_boutique', 'Koki Mokolo')
            ->assertJsonPath('vendeurs.0.produits.0.nom', 'Koki');

        $this->getJson("/api/client/vendeurs/{$vendeur->id}")
            ->assertOk()
            ->assertJsonPath('vendeur.id', $vendeur->id);
    }
}
