<?php

namespace Tests\Feature;

use App\Models\Client;
use App\Models\Commande;
use App\Models\Complement;
use App\Models\Paiement;
use App\Models\Produit;
use App\Models\User;
use App\Models\Vendeur;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class VendeurCommandeWorkflowTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        config([
            'services.mtn_momo.subscription_key' => 'subscription-test',
            'services.mtn_momo.api_user' => 'api-user-test',
            'services.mtn_momo.api_key' => 'api-key-test',
            'services.mtn_momo.callback_base_url' => 'https://api.hot-koki.test',
        ]);

        Http::fake(function (Request $request) {
            if (str_ends_with($request->url(), '/collection/token/')) {
                return Http::response(['access_token' => 'token-test']);
            }

            return Http::response([], 202);
        });
    }

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
        $commandePublicId = $creation->json('commande.public_id');

        $paiement = $this->postJson("/api/commandes/{$commandePublicId}/paiements", [
            'fournisseur' => Paiement::FOURNISSEUR_MTN_MOMO,
            'telephone' => '677123456',
        ])
            ->assertCreated()
            ->assertJsonPath('paiement.statut', Paiement::STATUT_EN_ATTENTE)
            ->assertJsonPath('paiement.montant', '1000.00');

        $this->getJson('/api/commandes')
            ->assertOk()
            ->assertJsonPath('0.id', $commandeId);

        Sanctum::actingAs($autreVendeurUser);

        $this->patchJson("/api/vendeur/commandes/{$commandePublicId}/statut", [
            'statut' => Commande::STATUT_RECUE,
        ])->assertForbidden();

        Sanctum::actingAs($vendeurUser);

        $this->getJson('/api/vendeur/commandes')
            ->assertOk()
            ->assertJsonCount(1)
            ->assertJsonPath('0.id', $commandeId)
            ->assertJsonPath('0.statut', Commande::STATUT_EN_ATTENTE_PAIEMENT);

        $this->getJson("/api/vendeur/commandes/{$commandePublicId}")
            ->assertOk()
            ->assertJsonPath('id', $commandeId);

        $this->changerStatut($commandePublicId, Commande::STATUT_RECUE)->assertUnprocessable();

        // En production, seul le resultat verifie chez MTN appellera cette methode.
        Paiement::findOrFail($paiement->json('paiement.id'))->confirmerReussite('mtn-test-1');

        $this->changerStatut($commandePublicId, Commande::STATUT_LIVREE)
            ->assertUnprocessable();

        $this->changerStatut($commandePublicId, Commande::STATUT_PREPARATION)->assertOk();
        $this->changerStatut($commandePublicId, Commande::STATUT_EN_LIVRAISON)->assertOk();
        $this->changerStatut($commandePublicId, Commande::STATUT_LIVREE)->assertOk();

        $this->changerStatut($commandePublicId, Commande::STATUT_ANNULEE)
            ->assertUnprocessable();

        $this->assertDatabaseHas('commandes', [
            'id' => $commandeId,
            'statut' => Commande::STATUT_LIVREE,
        ]);
    }

    private function changerStatut(string $commandeId, string $statut)
    {
        return $this->patchJson("/api/vendeur/commandes/{$commandeId}/statut", [
            'statut' => $statut,
        ]);
    }
}
