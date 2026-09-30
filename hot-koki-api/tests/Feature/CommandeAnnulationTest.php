<?php

namespace Tests\Feature;

use App\Models\Client;
use App\Models\Commande;
use App\Models\User;
use App\Models\Vendeur;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class CommandeAnnulationTest extends TestCase
{
    use RefreshDatabase;

    public function test_annulation_client_nest_plus_exposee(): void
    {
        [$clientUser, $client] = $this->creerClient();
        $vendeur = $this->creerVendeur();
        $commande = $this->creerCommande($client, $vendeur, Commande::STATUT_EN_ATTENTE_PAIEMENT);

        Sanctum::actingAs($clientUser);

        $this->patchJson("/api/commandes/{$commande->public_id}/annuler")
            ->assertNotFound();
    }

    public function test_ancienne_route_annulation_reste_introuvable_pour_toute_commande(): void
    {
        [$clientUser, $client] = $this->creerClient();
        [, $autreClient] = $this->creerClient();
        $vendeur = $this->creerVendeur();
        $commandeEnPreparation = $this->creerCommande($client, $vendeur, Commande::STATUT_RECUE);
        $commandeEtrangere = $this->creerCommande($autreClient, $vendeur, Commande::STATUT_EN_ATTENTE_PAIEMENT);

        Sanctum::actingAs($clientUser);

        $this->patchJson("/api/commandes/{$commandeEnPreparation->public_id}/annuler")
            ->assertNotFound();

        $this->patchJson("/api/commandes/{$commandeEtrangere->public_id}/annuler")
            ->assertNotFound();

        $this->assertDatabaseHas('commandes', [
            'id' => $commandeEtrangere->id,
            'statut' => Commande::STATUT_EN_ATTENTE_PAIEMENT,
        ]);
    }

    public function test_vendeur_ne_peut_plus_annuler_une_commande_payee(): void
    {
        [, $client] = $this->creerClient();
        [$vendeurUser, $vendeur] = $this->creerVendeurAvecUtilisateur();
        $commande = $this->creerCommande($client, $vendeur, Commande::STATUT_RECUE);

        Sanctum::actingAs($vendeurUser);

        $this->patchJson("/api/vendeur/commandes/{$commande->public_id}/statut", [
            'statut' => Commande::STATUT_ANNULEE,
        ])->assertUnprocessable();

        $this->assertDatabaseHas('commandes', [
            'id' => $commande->id,
            'statut' => Commande::STATUT_RECUE,
        ]);
    }

    /** @return array{User, Client} */
    private function creerClient(): array
    {
        $user = User::factory()->create(['role' => 'client']);
        $client = Client::create(['user_id' => $user->id, 'nom' => 'Client Test']);

        return [$user, $client];
    }

    private function creerVendeur(): Vendeur
    {
        return $this->creerVendeurAvecUtilisateur()[1];
    }

    /** @return array{User, Vendeur} */
    private function creerVendeurAvecUtilisateur(): array
    {
        $user = User::factory()->create(['role' => 'vendeur']);
        $vendeur = Vendeur::create([
            'user_id' => $user->id,
            'nom_boutique' => 'Koki Test',
        ]);

        return [$user, $vendeur];
    }

    private function creerCommande(Client $client, Vendeur $vendeur, string $statut): Commande
    {
        return Commande::create([
            'client_id' => $client->id,
            'vendeur_id' => $vendeur->id,
            'statut' => $statut,
            'adresse_livraison' => 'Douala',
            'latitude_client' => 4.0511,
            'longitude_client' => 9.7679,
            'sous_total' => 1000,
            'frais_livraison' => 300,
            'total' => 1300,
        ]);
    }
}
