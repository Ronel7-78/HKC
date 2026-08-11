<?php

// Ces tests verifient la regle d'un seul complement par ligne de commande.

namespace Tests\Feature;

use App\Models\Client;
use App\Models\Complement;
use App\Models\Produit;
use App\Models\User;
use App\Models\Vendeur;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class CommandeComplementTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Une ligne sans complement doit etre refusee.
     */
    public function test_commande_requires_one_complement(): void
    {
        [$produit] = $this->prepareCatalogue();

        $this->postJson('/api/commandes/preview', $this->panier($produit, []))
            ->assertUnprocessable()
            ->assertJsonValidationErrors('items.0.complements');
    }

    /**
     * Une ligne contenant un seul complement autorise doit etre acceptee.
     */
    public function test_commande_accepts_one_authorized_complement(): void
    {
        [$produit, $complement] = $this->prepareCatalogue();

        $this->postJson('/api/commandes/preview', $this->panier($produit, [$complement->id]))
            ->assertOk()
            ->assertJsonPath('sous_total', 1000)
            ->assertJsonPath('total', 1300);
    }

    /**
     * Plusieurs complements sur la meme ligne doivent etre refuses.
     */
    public function test_commande_rejects_several_complements(): void
    {
        [$produit, $complement] = $this->prepareCatalogue();
        $autreComplement = Complement::create(['nom' => 'Patate & macabo']);
        $produit->complements()->attach($autreComplement->id);

        $this->postJson(
            '/api/commandes/preview',
            $this->panier($produit, [$complement->id, $autreComplement->id]),
        )
            ->assertUnprocessable()
            ->assertJsonValidationErrors('items.0.complements');
    }

    /**
     * Un complement lie a un autre produit doit etre refuse.
     */
    public function test_commande_rejects_complement_from_another_product(): void
    {
        [$produit] = $this->prepareCatalogue();
        $complementNonAutorise = Complement::create(['nom' => 'Complement non autorise']);

        $this->postJson(
            '/api/commandes/preview',
            $this->panier($produit, [$complementNonAutorise->id]),
        )->assertUnprocessable();
    }

    /**
     * Prepare un client, un vendeur disponible et un produit avec son complement.
     *
     * @return array{Produit, Complement}
     */
    private function prepareCatalogue(): array
    {
        // Le client authentifie peut acceder aux routes de commande.
        $clientUser = User::factory()->create(['role' => 'client']);
        Client::create([
            'user_id' => $clientUser->id,
            'nom' => 'Client Test',
        ]);
        Sanctum::actingAs($clientUser);

        // Le vendeur est disponible au meme emplacement que le client.
        $vendeurUser = User::factory()->create(['role' => 'vendeur']);
        $vendeur = Vendeur::create([
            'user_id' => $vendeurUser->id,
            'nom_boutique' => 'Koki Test',
            'latitude' => 4.0511,
            'longitude' => 9.7679,
            'statut_dispo' => 'disponible',
            'statut_compte' => 'actif',
        ]);

        // Le produit coute 1 000 et propose un complement unique.
        $produit = Produit::create([
            'nom' => 'Koki',
            'prix' => 1000,
        ]);
        $complement = Complement::create(['nom' => 'Banane plantain']);
        $produit->complements()->attach($complement->id);
        $vendeur->produits()->attach($produit->id, ['statut' => 'disponible']);

        return [$produit, $complement];
    }

    /**
     * Construit une requete de panier avec les complements demandes par le test.
     *
     * @param  array<int, int>  $complements
     * @return array<string, mixed>
     */
    private function panier(Produit $produit, array $complements): array
    {
        return [
            'items' => [[
                'produit_id' => $produit->id,
                'complements' => $complements,
            ]],
            'adresse_livraison' => 'Douala',
            'latitude_client' => 4.0511,
            'longitude_client' => 9.7679,
        ];
    }
}
