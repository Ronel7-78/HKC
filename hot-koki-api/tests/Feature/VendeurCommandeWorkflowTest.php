<?php

namespace Tests\Feature;

use App\Models\Client;
use App\Models\Commande;
use App\Models\Complement;
use App\Models\Produit;
use App\Models\User;
use App\Models\Vendeur;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class VendeurCommandeWorkflowTest extends TestCase
{
    use RefreshDatabase;

    public function test_vendeur_affecte_fait_evoluer_la_commande_dans_lordre(): void
    {
        $clientUser = User::factory()->create(['role' => 'client']);
        Client::create(['user_id' => $clientUser->id, 'nom' => 'Client Test']);

        $vendeurUser = User::factory()->create(['role' => 'vendeur']);
        $vendeur = Vendeur::create([
            'user_id' => $vendeurUser->id,
            'nom_boutique' => 'Koki Test',
            'latitude' => 4.0511,
            'longitude' => 9.7679,
            'statut_dispo' => 'disponible',
            'statut_compte' => 'actif',
        ]);

        $autreVendeurUser = User::factory()->create(['role' => 'vendeur']);
        Vendeur::create([
            'user_id' => $autreVendeurUser->id,
            'nom_boutique' => 'Autre vendeur',
            'latitude' => 10,
            'longitude' => 10,
            'statut_dispo' => 'disponible',
            'statut_compte' => 'actif',
        ]);

        $produit = Produit::create(['nom' => 'Koki', 'prix' => 1000]);
        $complement = Complement::create(['nom' => 'Banane plantain']);
        $produit->complements()->attach($complement->id);
        $vendeur->produits()->attach($produit->id, ['statut' => 'disponible']);

        Sanctum::actingAs($clientUser);

        $panier = [
            'items' => [[
                'produit_id' => $produit->id,
                'complements' => [$complement->id],
            ]],
            'adresse_livraison' => 'Douala',
            'latitude_client' => 4.0511,
            'longitude_client' => 9.7679,
        ];

        $this->postJson('/api/commandes/preview', $panier)
            ->assertOk()
            ->assertJsonPath('vendeur.id', $vendeur->id);

        // Le vendeur peut devenir indisponible entre l'apercu et la creation.
        $vendeur->update(['statut_dispo' => 'pause']);

        $this->postJson('/api/commandes', $panier + ['vendeur_id' => $vendeur->id])
            ->assertUnprocessable()
            ->assertJsonPath('code', 'VENDEUR_DEVENU_INELIGIBLE');

        $vendeur->update(['statut_dispo' => 'disponible']);

        $creation = $this->postJson('/api/commandes', $panier + ['vendeur_id' => $vendeur->id])
            ->assertCreated()
            ->assertJsonPath('commande.statut', Commande::STATUT_EN_ATTENTE_PAIEMENT)
            ->assertJsonPath('commande.vendeur_id', $vendeur->id);

        $commandeId = $creation->json('commande.id');

        $this->getJson('/api/commandes')
            ->assertOk()
            ->assertJsonPath('0.id', $commandeId);

        Sanctum::actingAs($autreVendeurUser);

        $this->patchJson("/api/vendeur/commandes/{$commandeId}/statut", [
            'statut' => Commande::STATUT_RECUE,
        ])->assertForbidden();

        Sanctum::actingAs($vendeurUser);

        $this->getJson('/api/vendeur/commandes')
            ->assertOk()
            ->assertJsonCount(1)
            ->assertJsonPath('0.id', $commandeId)
            ->assertJsonPath('0.statut', Commande::STATUT_EN_ATTENTE_PAIEMENT);

        $this->getJson("/api/vendeur/commandes/{$commandeId}")
            ->assertOk()
            ->assertJsonPath('id', $commandeId);

        $this->changerStatut($commandeId, Commande::STATUT_RECUE)->assertOk();

        $this->changerStatut($commandeId, Commande::STATUT_LIVREE)
            ->assertUnprocessable();

        $this->changerStatut($commandeId, Commande::STATUT_PREPARATION)->assertOk();
        $this->changerStatut($commandeId, Commande::STATUT_EN_LIVRAISON)->assertOk();
        $this->changerStatut($commandeId, Commande::STATUT_LIVREE)->assertOk();

        $this->changerStatut($commandeId, Commande::STATUT_ANNULEE)
            ->assertUnprocessable();

        $this->assertDatabaseHas('commandes', [
            'id' => $commandeId,
            'statut' => Commande::STATUT_LIVREE,
        ]);
    }

    private function changerStatut(int $commandeId, string $statut)
    {
        return $this->patchJson("/api/vendeur/commandes/{$commandeId}/statut", [
            'statut' => $statut,
        ]);
    }
}
