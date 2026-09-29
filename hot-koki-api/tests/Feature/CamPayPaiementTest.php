<?php

namespace Tests\Feature;

use App\Models\Client;
use App\Models\Commande;
use App\Models\Paiement;
use App\Models\User;
use App\Models\Vendeur;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class CamPayPaiementTest extends TestCase
{
    use RefreshDatabase;

    private ?array $statutCamPay = null;

    protected function setUp(): void
    {
        parent::setUp();

        Cache::forget('campay:access-token');
        config([
            'payments.gateway' => Paiement::PASSERELLE_CAMPAY,
            'services.campay.enabled' => true,
            'services.campay.environment' => 'DEV',
            'services.campay.base_url' => 'https://demo.campay.test',
            'services.campay.username' => 'campay-username-test',
            'services.campay.password' => 'campay-password-test',
            'services.campay.currency' => 'XAF',
            'services.campay.demo_amount' => 10,
            'services.campay.poll_max_attempts' => 12,
            'services.mtn_momo.enabled' => false,
            'services.orange_money.enabled' => false,
        ]);

        Http::fake(function (Request $request) {
            if (str_ends_with($request->url(), '/api/token/')) {
                return Http::response(['token' => 'campay-token-test']);
            }

            if (str_ends_with($request->url(), '/api/collect/')) {
                return Http::response([
                    'reference' => 'campay-reference-1',
                    'operator' => 'MTN',
                    'ussd_code' => '*126#',
                ]);
            }

            if (str_contains($request->url(), '/api/transaction/') && $this->statutCamPay) {
                return Http::response($this->statutCamPay);
            }

            return Http::response([], 404);
        });
    }

    public function test_mtn_et_orange_sont_proposes_via_campay(): void
    {
        [$user] = $this->creerClient();
        Sanctum::actingAs($user);

        $this->getJson('/api/paiements-moyens')
            ->assertOk()
            ->assertJsonPath('0.code', Paiement::FOURNISSEUR_MTN_MOMO)
            ->assertJsonPath('0.disponible', true)
            ->assertJsonPath('0.passerelle', Paiement::PASSERELLE_CAMPAY)
            ->assertJsonPath('1.code', Paiement::FOURNISSEUR_ORANGE_MONEY)
            ->assertJsonPath('1.disponible', true)
            ->assertJsonPath('1.passerelle', Paiement::PASSERELLE_CAMPAY);
    }

    public function test_campay_initie_une_collecte_sans_exposer_ses_secrets(): void
    {
        [$user, $client] = $this->creerClient();
        $commande = $this->creerCommande($client);
        Sanctum::actingAs($user);

        $this->postJson("/api/commandes/{$commande->public_id}/paiements", [
            'fournisseur' => Paiement::FOURNISSEUR_MTN_MOMO,
            'telephone' => '677123456',
        ])->assertCreated()
            ->assertJsonPath('paiement.passerelle', Paiement::PASSERELLE_CAMPAY)
            ->assertJsonPath('paiement.mode_test', true)
            ->assertJsonPath('paiement.statut', Paiement::STATUT_EN_ATTENTE)
            ->assertJsonMissingPath('paiement.donnees_operateur');

        Http::assertSent(fn (Request $request): bool => str_ends_with($request->url(), '/api/collect/')
            && $request->hasHeader('Authorization', 'Token campay-token-test')
            && $request['amount'] === '10'
            && $request['currency'] === 'XAF'
            && $request['from'] === '237677123456');
    }

    public function test_campay_confirme_uniquement_une_transaction_conforme(): void
    {
        [$user, $client] = $this->creerClient();
        $commande = $this->creerCommande($client);
        $paiement = $commande->paiements()->create([
            'passerelle' => Paiement::PASSERELLE_CAMPAY,
            'fournisseur' => Paiement::FOURNISSEUR_ORANGE_MONEY,
            'telephone' => '237690000010',
            'montant' => $commande->total,
            'devise' => 'XAF',
            'statut' => Paiement::STATUT_EN_ATTENTE,
            'reference_operateur' => 'campay-reference-1',
            'donnees_operateur' => ['reference' => 'campay-reference-1'],
        ]);
        $this->statutCamPay = [
            'reference' => 'campay-reference-1',
            'external_reference' => $paiement->reference_interne,
            'status' => 'SUCCESSFUL',
            'amount' => 10,
            'currency' => 'XAF',
            'operator' => 'ORANGE',
            'operator_reference' => 'OM-REF-1',
        ];
        Sanctum::actingAs($user);

        $this->postJson("/api/paiements/{$paiement->public_id}/synchroniser")
            ->assertOk()
            ->assertJsonPath('statut', Paiement::STATUT_REUSSI)
            ->assertJsonPath('commande.statut', Commande::STATUT_RECUE);
    }

    public function test_campay_accepte_une_reponse_sans_champs_optionnels_si_la_reference_correspond(): void
    {
        [$user, $client] = $this->creerClient();
        $commande = $this->creerCommande($client);
        $paiement = $commande->paiements()->create([
            'passerelle' => Paiement::PASSERELLE_CAMPAY,
            'fournisseur' => Paiement::FOURNISSEUR_MTN_MOMO,
            'telephone' => '237677777777',
            'montant' => $commande->total,
            'devise' => 'XAF',
            'statut' => Paiement::STATUT_EN_ATTENTE,
            'reference_operateur' => 'campay-reference-1',
            'donnees_operateur' => ['reference' => 'campay-reference-1'],
        ]);
        $this->statutCamPay = [
            'reference' => 'campay-reference-1',
            'status' => 'SUCCESSFUL',
            'operator' => 'MTN',
            'operator_reference' => 'MTN-REF-1',
        ];
        Sanctum::actingAs($user);

        $this->postJson("/api/paiements/{$paiement->public_id}/synchroniser")
            ->assertOk()
            ->assertJsonPath('statut', Paiement::STATUT_REUSSI);
    }

    public function test_numero_dun_autre_operateur_est_refuse_avant_lappel_campay(): void
    {
        [$user, $client] = $this->creerClient();
        $commande = $this->creerCommande($client);
        Sanctum::actingAs($user);

        $this->postJson("/api/commandes/{$commande->public_id}/paiements", [
            'fournisseur' => Paiement::FOURNISSEUR_MTN_MOMO,
            'telephone' => '699999999',
        ])->assertUnprocessable()
            ->assertJsonValidationErrors('telephone');

        $this->assertDatabaseCount('paiements', 0);
    }

    public function test_commande_expose_un_code_metier_lisible(): void
    {
        [, $client] = $this->creerClient();
        $commande = $this->creerCommande($client);

        $this->assertSame(
            'COM-HKC-'.str_pad((string) $commande->id, 6, '0', STR_PAD_LEFT).'-'.$commande->created_at->format('y'),
            $commande->code_commande,
        );
        $this->assertArrayHasKey('code_commande', $commande->toArray());
    }

    private function creerClient(): array
    {
        $user = User::factory()->create([
            'role' => 'client',
            'email_verified_at' => now(),
        ]);

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
            'sous_total' => 1300,
            'frais_livraison' => 0,
            'total' => 1300,
        ]);
    }
}
