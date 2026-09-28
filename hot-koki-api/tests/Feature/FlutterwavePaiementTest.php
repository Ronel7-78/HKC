<?php

namespace Tests\Feature;

use App\Jobs\VerifierPaiementFlutterwave;
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

class FlutterwavePaiementTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        config([
            'payments.gateway' => Paiement::PASSERELLE_FLUTTERWAVE,
            'services.flutterwave.enabled' => true,
            'services.flutterwave.environment' => 'sandbox',
            'services.flutterwave.base_url' => 'https://api.flutterwave.test/v3',
            'services.flutterwave.secret_key' => 'FLWSECK_TEST-secret',
            'services.flutterwave.webhook_secret' => 'webhook-secret',
            'services.flutterwave.callback_base_url' => 'https://api.hot-koki.test',
            'services.flutterwave.currency' => 'XAF',
            'services.flutterwave.country' => 'CM',
            'services.mtn_momo.enabled' => false,
            'services.orange_money.enabled' => false,
        ]);
    }

    public function test_mtn_et_orange_sont_proposes_via_flutterwave(): void
    {
        [$user] = $this->creerClient();
        Sanctum::actingAs($user);

        $this->getJson('/api/paiements-moyens')
            ->assertOk()
            ->assertJsonPath('0.code', Paiement::FOURNISSEUR_MTN_MOMO)
            ->assertJsonPath('0.disponible', true)
            ->assertJsonPath('0.passerelle', Paiement::PASSERELLE_FLUTTERWAVE)
            ->assertJsonPath('1.code', Paiement::FOURNISSEUR_ORANGE_MONEY)
            ->assertJsonPath('1.disponible', true);
    }

    public function test_flutterwave_initie_mtn_avec_le_montant_de_la_commande(): void
    {
        Http::fake([
            'api.flutterwave.test/v3/charges*' => Http::response([
                'status' => 'success',
                'data' => [
                    'id' => 9876,
                    'status' => 'pending',
                    'flw_ref' => 'FLW-MOCK-1',
                    'auth_url' => 'https://checkout.flutterwave.test/pay/1',
                ],
            ]),
        ]);

        [$user, $client] = $this->creerClient();
        $commande = $this->creerCommande($client);
        Sanctum::actingAs($user);

        $this->postJson("/api/commandes/{$commande->public_id}/paiements", [
            'fournisseur' => Paiement::FOURNISSEUR_MTN_MOMO,
            'telephone' => '677123456',
        ])->assertCreated()
            ->assertJsonPath('paiement.passerelle', Paiement::PASSERELLE_FLUTTERWAVE)
            ->assertJsonPath('paiement.mode_test', true)
            ->assertJsonPath('paiement.url_paiement', 'https://checkout.flutterwave.test/pay/1');

        Http::assertSent(fn (Request $request): bool => str_contains($request->url(), '/charges?type=mobile_money_franco')
            && $request['network'] === 'MTN'
            && $request['amount'] === 1300
            && $request['currency'] === 'XAF'
            && $request['country'] === 'CM'
            && $request['redirect_url'] === 'https://api.hot-koki.test/paiements/flutterwave/retour');
    }

    public function test_flutterwave_confirme_uniquement_une_transaction_conforme(): void
    {
        [$user, $client] = $this->creerClient();
        $commande = $this->creerCommande($client);
        $paiement = $commande->paiements()->create([
            'passerelle' => Paiement::PASSERELLE_FLUTTERWAVE,
            'fournisseur' => Paiement::FOURNISSEUR_ORANGE_MONEY,
            'telephone' => '237690000010',
            'montant' => $commande->total,
            'devise' => 'XAF',
            'statut' => Paiement::STATUT_EN_ATTENTE,
            'donnees_operateur' => ['transaction_id' => 9876],
        ]);
        Http::fake([
            'api.flutterwave.test/v3/transactions/9876/verify' => Http::response([
                'status' => 'success',
                'data' => [
                    'id' => 9876,
                    'status' => 'successful',
                    'tx_ref' => $paiement->reference_interne,
                    'flw_ref' => 'FLW-MOCK-2',
                    'currency' => 'XAF',
                    'amount' => 1300,
                ],
            ]),
        ]);
        Sanctum::actingAs($user);

        $this->postJson("/api/paiements/{$paiement->public_id}/synchroniser")
            ->assertOk()
            ->assertJsonPath('statut', Paiement::STATUT_REUSSI)
            ->assertJsonPath('commande.statut', Commande::STATUT_RECUE);
    }

    public function test_webhook_flutterwave_exige_le_secret_et_lance_une_verification(): void
    {
        Queue::fake();
        [, $client] = $this->creerClient();
        $commande = $this->creerCommande($client);
        $paiement = $commande->paiements()->create([
            'passerelle' => Paiement::PASSERELLE_FLUTTERWAVE,
            'fournisseur' => Paiement::FOURNISSEUR_MTN_MOMO,
            'telephone' => '237677123456',
            'montant' => $commande->total,
            'devise' => 'XAF',
        ]);

        $payload = ['data' => ['tx_ref' => $paiement->reference_interne]];
        $this->postJson('/api/webhooks/flutterwave', $payload)->assertUnauthorized();
        $this->withHeader('verif-hash', 'webhook-secret')
            ->postJson('/api/webhooks/flutterwave', $payload)
            ->assertOk();

        Queue::assertPushed(VerifierPaiementFlutterwave::class, fn ($job) => $job->paiementId === $paiement->id);
    }

    private function creerClient(): array
    {
        $user = User::factory()->create([
            'role' => 'client',
            'email_verified_at' => now(),
        ]);
        $client = Client::create(['user_id' => $user->id, 'nom' => 'Client Test']);

        return [$user, $client];
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
            'sous_total' => 1300,
            'frais_livraison' => 0,
            'total' => 1300,
            'statut' => Commande::STATUT_EN_ATTENTE_PAIEMENT,
            'adresse_livraison' => 'Douala',
            'latitude_client' => 4.0511,
            'longitude_client' => 9.7679,
        ]);
    }
}
