<?php

namespace Tests\Feature;

use App\Models\Client;
use App\Models\Commande;
use App\Models\Paiement;
use App\Models\User;
use App\Models\Vendeur;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PaiementTest extends TestCase
{
    use RefreshDatabase;

    public function test_client_cree_une_seule_tentative_active_avec_le_montant_de_la_commande(): void
    {
        [$user, $client] = $this->creerClient();
        $commande = $this->creerCommande($client);
        Sanctum::actingAs($user);

        $payload = [
            'fournisseur' => Paiement::FOURNISSEUR_MTN_MOMO,
            'telephone' => '+237677123456',
            'montant' => 1,
        ];

        $creation = $this->postJson("/api/commandes/{$commande->id}/paiements", $payload)
            ->assertCreated()
            ->assertJsonPath('paiement.montant', '1300.00')
            ->assertJsonPath('paiement.devise', 'XAF')
            ->assertJsonPath('paiement.telephone', '237677123456')
            ->assertJsonPath('paiement.statut', Paiement::STATUT_INITIE);

        $paiementId = $creation->json('paiement.id');

        $this->postJson("/api/commandes/{$commande->id}/paiements", $payload)
            ->assertOk()
            ->assertJsonPath('paiement.id', $paiementId);

        $this->assertDatabaseCount('paiements', 1);
    }

    public function test_paiement_reussi_fait_passer_la_commande_a_recue_une_seule_fois(): void
    {
        [, $client] = $this->creerClient();
        $commande = $this->creerCommande($client);
        $paiement = $commande->paiements()->create([
            'fournisseur' => Paiement::FOURNISSEUR_MTN_MOMO,
            'telephone' => '237677123456',
            'montant' => $commande->total,
            'devise' => 'XAF',
        ]);

        $paiement->confirmerReussite('reference-mtn', ['status' => 'SUCCESSFUL']);
        $paiement->confirmerReussite('reference-mtn', ['status' => 'SUCCESSFUL']);

        $this->assertDatabaseHas('paiements', [
            'id' => $paiement->id,
            'statut' => Paiement::STATUT_REUSSI,
            'reference_operateur' => 'reference-mtn',
        ]);
        $this->assertDatabaseHas('commandes', [
            'id' => $commande->id,
            'statut' => Commande::STATUT_RECUE,
        ]);
    }

    public function test_client_ne_peut_pas_creer_ou_consulter_le_paiement_dun_autre_client(): void
    {
        [$premierUser] = $this->creerClient();
        [, $secondClient] = $this->creerClient();
        $commande = $this->creerCommande($secondClient);
        $paiement = $commande->paiements()->create([
            'fournisseur' => Paiement::FOURNISSEUR_MTN_MOMO,
            'telephone' => '237677123456',
            'montant' => $commande->total,
            'devise' => 'XAF',
        ]);
        Sanctum::actingAs($premierUser);

        $this->postJson("/api/commandes/{$commande->id}/paiements", [
            'fournisseur' => Paiement::FOURNISSEUR_MTN_MOMO,
            'telephone' => '677123456',
        ])->assertForbidden();

        $this->getJson("/api/paiements/{$paiement->id}")->assertForbidden();
    }

    /** @return array{User, Client} */
    private function creerClient(): array
    {
        $user = User::factory()->create(['role' => 'client']);

        return [$user, Client::create(['user_id' => $user->id, 'nom' => 'Client Test'])];
    }

    private function creerCommande(Client $client): Commande
    {
        $vendeurUser = User::factory()->create(['role' => 'vendeur']);
        $vendeur = Vendeur::create([
            'user_id' => $vendeurUser->id,
            'nom_boutique' => 'Koki Test',
        ]);

        return Commande::create([
            'client_id' => $client->id,
            'vendeur_id' => $vendeur->id,
            'statut' => Commande::STATUT_EN_ATTENTE_PAIEMENT,
            'adresse_livraison' => 'Douala',
            'latitude_client' => 4.0511,
            'longitude_client' => 9.7679,
            'sous_total' => 1000,
            'frais_livraison' => 300,
            'total' => 1300,
        ]);
    }
}
