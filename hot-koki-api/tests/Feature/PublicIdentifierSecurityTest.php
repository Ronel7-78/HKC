<?php

namespace Tests\Feature;

use App\Models\Client;
use App\Models\Commande;
use App\Models\User;
use App\Models\Vendeur;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PublicIdentifierSecurityTest extends TestCase
{
    use RefreshDatabase;

    public function test_un_identifiant_numerique_interne_ne_resout_plus_une_commande(): void
    {
        [$user, $client, $vendeur] = $this->context();
        $commande = $this->commande($client, $vendeur);
        Sanctum::actingAs($user);

        $this->getJson("/api/commandes/{$commande->id}")->assertNotFound();
        $this->getJson("/api/commandes/{$commande->public_id}")
            ->assertOk()
            ->assertJsonPath('public_id', $commande->public_id);
    }

    public function test_un_uuid_public_ne_contourne_pas_le_controle_dappartenance(): void
    {
        [$premierUser, , $vendeur] = $this->context();
        $autreUser = User::factory()->create(['role' => 'client']);
        $autreClient = Client::create(['user_id' => $autreUser->id, 'nom' => 'Autre']);
        $commande = $this->commande($autreClient, $vendeur);
        Sanctum::actingAs($premierUser);

        $this->getJson("/api/commandes/{$commande->public_id}")->assertNotFound();
    }

    /** @return array{User, Client, Vendeur} */
    private function context(): array
    {
        $user = User::factory()->create(['role' => 'client']);
        $client = Client::create(['user_id' => $user->id, 'nom' => 'Client']);
        $vendeurUser = User::factory()->create(['role' => 'vendeur']);
        $vendeur = Vendeur::create([
            'user_id' => $vendeurUser->id,
            'nom_boutique' => 'Koki sécurisé',
        ]);

        return [$user, $client, $vendeur];
    }

    private function commande(Client $client, Vendeur $vendeur): Commande
    {
        return Commande::create([
            'client_id' => $client->id,
            'vendeur_id' => $vendeur->id,
            'statut' => Commande::STATUT_EN_ATTENTE_PAIEMENT,
            'adresse_livraison' => 'Douala',
            'latitude_client' => 4.05,
            'longitude_client' => 9.70,
            'sous_total' => 1000,
            'frais_livraison' => 300,
            'total' => 1300,
        ]);
    }
}
