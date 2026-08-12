<?php

namespace Tests\Feature;

use App\Models\Client;
use App\Models\Commande;
use App\Models\User;
use App\Models\Vendeur;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ClientCommandeAccessTest extends TestCase
{
    use RefreshDatabase;

    public function test_client_consulte_uniquement_ses_commandes(): void
    {
        $vendeurUser = User::factory()->create(['role' => 'vendeur']);
        $vendeur = Vendeur::create([
            'user_id' => $vendeurUser->id,
            'nom_boutique' => 'Koki Test',
        ]);

        [$premierUser, $premierClient] = $this->creerClient('Premier client');
        [, $secondClient] = $this->creerClient('Second client');

        $commandeDuClient = $this->creerCommande($premierClient, $vendeur, 'Bonamoussadi');
        $commandeEtrangere = $this->creerCommande($secondClient, $vendeur, 'Akwa');

        Sanctum::actingAs($premierUser);

        $this->getJson('/api/commandes')
            ->assertOk()
            ->assertJsonCount(1)
            ->assertJsonPath('0.id', $commandeDuClient->id);

        $this->getJson("/api/commandes/{$commandeDuClient->id}")
            ->assertOk()
            ->assertJsonPath('id', $commandeDuClient->id)
            ->assertJsonPath('adresse_livraison', 'Bonamoussadi');

        $this->getJson("/api/commandes/{$commandeEtrangere->id}")
            ->assertForbidden()
            ->assertJsonPath('message', 'Cette commande n\'appartient pas à ce client.');
    }

    /** @return array{User, Client} */
    private function creerClient(string $nom): array
    {
        $user = User::factory()->create(['role' => 'client']);
        $client = Client::create(['user_id' => $user->id, 'nom' => $nom]);

        return [$user, $client];
    }

    private function creerCommande(Client $client, Vendeur $vendeur, string $adresse): Commande
    {
        return Commande::create([
            'client_id' => $client->id,
            'vendeur_id' => $vendeur->id,
            'statut' => Commande::STATUT_EN_ATTENTE_PAIEMENT,
            'adresse_livraison' => $adresse,
            'latitude_client' => 4.0511,
            'longitude_client' => 9.7679,
            'sous_total' => 1000,
            'frais_livraison' => 300,
            'total' => 1300,
        ]);
    }
}
