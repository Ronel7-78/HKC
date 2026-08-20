<?php

namespace Tests\Feature;

use App\Jobs\VerifierPaiementMtn;
use App\Models\Client;
use App\Models\Commande;
use App\Models\Paiement;
use App\Models\User;
use App\Models\Vendeur;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Queue;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PaiementTest extends TestCase
{
    use RefreshDatabase;

    private ?array $statutMtn = null;

    protected function setUp(): void
    {
        parent::setUp();

        config([
            'services.mtn_momo.base_url' => 'https://sandbox.momodeveloper.mtn.com',
            'services.mtn_momo.target_environment' => 'sandbox',
            'services.mtn_momo.currency' => 'EUR',
            'services.mtn_momo.subscription_key' => 'subscription-test',
            'services.mtn_momo.api_user' => 'api-user-test',
            'services.mtn_momo.api_key' => 'api-key-test',
            'services.mtn_momo.callback_base_url' => 'https://api.hot-koki.test',
        ]);

        Http::fake(function (Request $request) {
            if (str_ends_with($request->url(), '/collection/token/')) {
                return Http::response([
                    'access_token' => 'token-test',
                    'expires_in' => 3600,
                ]);
            }

            if ($request->method() === 'GET' && $this->statutMtn) {
                return Http::response($this->statutMtn);
            }

            return Http::response([], 202);
        });
    }

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

        $creation = $this->postJson("/api/commandes/{$commande->public_id}/paiements", $payload)
            ->assertCreated()
            ->assertJsonPath('paiement.montant', '1300.00')
            ->assertJsonPath('paiement.devise', 'XAF')
            ->assertJsonPath('paiement.telephone_masque', '23767****456')
            ->assertJsonPath('paiement.statut', Paiement::STATUT_EN_ATTENTE);

        $paiementId = $creation->json('paiement.id');
        $this->assertSame('237677123456', Paiement::findOrFail($paiementId)->telephone);

        $this->postJson("/api/commandes/{$commande->public_id}/paiements", $payload)
            ->assertOk()
            ->assertJsonPath('paiement.id', $paiementId);

        $this->assertDatabaseCount('paiements', 1);

        Http::assertSent(function (Request $request) use ($paiementId) {
            if (! str_ends_with($request->url(), '/collection/v1_0/requesttopay')) {
                return false;
            }

            $paiement = Paiement::findOrFail($paiementId);

            return $request->hasHeader('X-Reference-Id', $paiement->reference_interne)
                && $request['amount'] === '1300.00'
                && $request['currency'] === 'EUR'
                && $request['payer']['partyId'] === '237677123456';
        });
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
            'prochaine_verification_le' => null,
        ]);
        $this->assertDatabaseHas('commandes', [
            'id' => $commande->id,
            'statut' => Commande::STATUT_RECUE,
        ]);
    }

    public function test_numero_mtn_fictif_est_accepte_uniquement_dans_le_sandbox(): void
    {
        [$user, $client] = $this->creerClient();
        $commande = $this->creerCommande($client);
        Sanctum::actingAs($user);

        $this->postJson("/api/commandes/{$commande->public_id}/paiements", [
            'fournisseur' => Paiement::FOURNISSEUR_MTN_MOMO,
            'telephone' => '46733123401',
        ])
            ->assertCreated()
            ->assertJsonPath('paiement.telephone_masque', '46733****401');
    }

    public function test_orange_est_annonce_mais_ne_cree_aucun_paiement_tant_que_non_configure(): void
    {
        [$user, $client] = $this->creerClient();
        $commande = $this->creerCommande($client);
        Sanctum::actingAs($user);

        $this->getJson('/api/paiements-moyens')
            ->assertOk()
            ->assertJsonPath('0.code', Paiement::FOURNISSEUR_MTN_MOMO)
            ->assertJsonPath('0.disponible', true)
            ->assertJsonPath('1.code', Paiement::FOURNISSEUR_ORANGE_MONEY)
            ->assertJsonPath('1.disponible', false);

        $this->postJson("/api/commandes/{$commande->public_id}/paiements", [
            'fournisseur' => Paiement::FOURNISSEUR_ORANGE_MONEY,
            'telephone' => '690000010',
        ])->assertStatus(503)
            ->assertJsonPath('code', 'ORANGE_MONEY_INDISPONIBLE');

        $this->assertDatabaseCount('paiements', 0);
    }

    public function test_tentative_restee_initiee_est_renvoyee_a_mtn_au_lieu_de_rester_bloquee(): void
    {
        [$user, $client] = $this->creerClient();
        $commande = $this->creerCommande($client);
        $paiement = $commande->paiements()->create([
            'fournisseur' => Paiement::FOURNISSEUR_MTN_MOMO,
            'telephone' => '46733123401',
            'montant' => $commande->total,
            'devise' => 'XAF',
            'statut' => Paiement::STATUT_INITIE,
        ]);
        Sanctum::actingAs($user);

        $this->postJson("/api/commandes/{$commande->public_id}/paiements", [
            'fournisseur' => Paiement::FOURNISSEUR_MTN_MOMO,
            'telephone' => '46733123401',
        ])->assertOk()->assertJsonPath('paiement.statut', Paiement::STATUT_EN_ATTENTE);

        Http::assertSent(fn (Request $request) => str_ends_with(
            $request->url(),
            '/collection/v1_0/requesttopay'
        ) && $request->hasHeader('X-Reference-Id', $paiement->reference_interne));
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

        $this->postJson("/api/commandes/{$commande->public_id}/paiements", [
            'fournisseur' => Paiement::FOURNISSEUR_MTN_MOMO,
            'telephone' => '677123456',
        ])->assertForbidden();

        $this->getJson("/api/paiements/{$paiement->public_id}")->assertForbidden();
    }

    public function test_synchronisation_verifie_le_succes_chez_mtn_avant_de_recevoir_la_commande(): void
    {
        [$user, $client] = $this->creerClient();
        $commande = $this->creerCommande($client);
        $paiement = $commande->paiements()->create([
            'fournisseur' => Paiement::FOURNISSEUR_MTN_MOMO,
            'telephone' => '237677123456',
            'montant' => $commande->total,
            'devise' => 'XAF',
            'statut' => Paiement::STATUT_EN_ATTENTE,
        ]);

        $this->statutMtn = [
            'status' => 'SUCCESSFUL',
            'financialTransactionId' => 'mtn-transaction-1',
            'payer' => ['partyId' => '237677123456'],
        ];
        Sanctum::actingAs($user);

        $this->postJson("/api/paiements/{$paiement->public_id}/synchroniser")
            ->assertOk()
            ->assertJsonPath('statut', Paiement::STATUT_REUSSI)
            ->assertJsonPath('commande.statut', Commande::STATUT_RECUE)
            ->assertJsonMissingPath('donnees_operateur')
            ->assertJsonMissingPath('telephone');
    }

    public function test_callback_valide_declenche_une_verification_asynchrone(): void
    {
        Queue::fake();
        [, $client] = $this->creerClient();
        $commande = $this->creerCommande($client);
        $token = str_repeat('a', 64);
        $paiement = $commande->paiements()->create([
            'fournisseur' => Paiement::FOURNISSEUR_MTN_MOMO,
            'telephone' => '237677123456',
            'montant' => $commande->total,
            'devise' => 'XAF',
            'statut' => Paiement::STATUT_EN_ATTENTE,
            'callback_hash' => hash('sha256', $token),
        ]);

        $this->postJson('/api/webhooks/mtn-momo/'.$token, [
            'status' => 'SUCCESSFUL',
        ])->assertOk();

        $this->assertDatabaseHas('paiements', [
            'id' => $paiement->id,
            'statut' => Paiement::STATUT_EN_ATTENTE,
        ]);
        Queue::assertPushed(VerifierPaiementMtn::class, fn ($job) => $job->paiementId === $paiement->id);
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
