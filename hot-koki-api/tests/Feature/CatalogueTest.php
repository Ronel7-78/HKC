<?php

namespace Tests\Feature;

use App\Models\Complement;
use App\Models\Produit;
use App\Models\User;
use App\Models\Vendeur;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CatalogueTest extends TestCase
{
    use RefreshDatabase;

    public function test_catalogue_public_indique_la_disponibilite_reelle(): void
    {
        $produit = Produit::create(['nom' => 'Koki', 'prix' => 500]);
        $complement = Complement::create(['nom' => 'Manioc']);
        $produit->complements()->attach($complement);
        $user = User::factory()->create(['role' => 'vendeur']);
        $vendeur = Vendeur::create([
            'user_id' => $user->id,
            'nom_boutique' => 'Chez Mama',
            'statut_compte' => 'actif',
            'statut_dispo' => 'disponible',
        ]);
        $vendeur->produits()->attach($produit, ['statut' => 'disponible']);

        $this->getJson('/api/catalogue')
            ->assertOk()
            ->assertJsonPath('produits.0.nom', 'Koki')
            ->assertJsonPath('produits.0.complements.0.nom', 'Manioc')
            ->assertJsonPath('produits.0.disponible', true)
            ->assertJsonPath('produits.0.vendeurs_disponibles', 1);
    }
}
