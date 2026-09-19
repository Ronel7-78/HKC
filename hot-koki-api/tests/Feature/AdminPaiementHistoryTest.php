<?php

namespace Tests\Feature;

use App\Models\Admin;
use App\Models\Client;
use App\Models\Commande;
use App\Models\Paiement;
use App\Models\User;
use App\Models\Vendeur;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminPaiementHistoryTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_consulte_un_historique_unifie_et_filtrable(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        Admin::create(['user_id' => $admin->id, 'nom' => 'Administrateur']);
        [$commande, $mtn] = $this->createPayment(Paiement::FOURNISSEUR_MTN_MOMO, 'reussi', 4500);
        $this->createPayment(Paiement::FOURNISSEUR_ORANGE_MONEY, 'echoue', 2000);

        Sanctum::actingAs($admin);

        $this->getJson('/api/admin/paiements?fournisseur=mtn_momo&statut=reussi')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $mtn->public_id)
            ->assertJsonPath('data.0.operateur', Paiement::FOURNISSEUR_MTN_MOMO)
            ->assertJsonPath('data.0.commande.id', $commande->public_id)
            ->assertJsonPath('data.0.montant', '4500.00')
            ->assertJsonMissingPath('data.0.montant_attribuable_vendeur')
            ->assertJsonMissingPath('data.0.telephone');
    }

    public function test_admin_consulte_la_chronologie_sans_donnees_operateur_sensibles(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        Admin::create(['user_id' => $admin->id, 'nom' => 'Administrateur']);
        [, $paiement] = $this->createPayment(Paiement::FOURNISSEUR_MTN_MOMO, Paiement::STATUT_INITIE, 3000);
        $paiement->update(['statut' => Paiement::STATUT_EN_ATTENTE]);
        $paiement->confirmerReussite('MTN-REFERENCE-123', ['secret' => 'non expose']);

        Sanctum::actingAs($admin);

        $this->getJson('/api/admin/paiements/'.$paiement->public_id)
            ->assertOk()
            ->assertJsonPath('reference_operateur', 'MTN-REFERENCE-123')
            ->assertJsonCount(3, 'evenements')
            ->assertJsonPath('evenements.0.nouveau_statut', Paiement::STATUT_INITIE)
            ->assertJsonPath('evenements.1.nouveau_statut', Paiement::STATUT_EN_ATTENTE)
            ->assertJsonPath('evenements.2.nouveau_statut', Paiement::STATUT_REUSSI)
            ->assertJsonMissingPath('donnees_operateur')
            ->assertJsonMissingPath('reference_interne');
    }

    public function test_un_client_ne_peut_pas_consulter_l_historique_admin(): void
    {
        Sanctum::actingAs(User::factory()->create(['role' => 'client']));

        $this->getJson('/api/admin/paiements')->assertForbidden();
    }

    private function createPayment(string $provider, string $status, int $amount): array
    {
        $client = Client::create([
            'user_id' => User::factory()->create(['role' => 'client'])->id,
            'nom' => 'Client historique',
        ]);
        $vendeur = Vendeur::create([
            'user_id' => User::factory()->create(['role' => 'vendeur'])->id,
            'nom_boutique' => 'Vendeur historique',
        ]);
        $commande = Commande::create([
            'client_id' => $client->id,
            'vendeur_id' => $vendeur->id,
            'statut' => Commande::STATUT_EN_ATTENTE_PAIEMENT,
            'adresse_livraison' => 'Bertoua',
            'latitude_client' => 4.58,
            'longitude_client' => 13.68,
            'sous_total' => $amount,
            'frais_livraison' => 0,
            'total' => $amount,
        ]);
        $paiement = $commande->paiements()->create([
            'fournisseur' => $provider,
            'telephone' => '237670000000',
            'montant' => $amount,
            'devise' => 'XAF',
            'statut' => $status,
        ]);

        return [$commande, $paiement];
    }
}
