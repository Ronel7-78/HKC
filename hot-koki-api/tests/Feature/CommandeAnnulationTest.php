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

    public function test_client_annule_sa_commande_avant_la_preparation(): void
    {
        [$clientUser, $client] = $this->creerClient();
        $vendeur = $this->creerVendeur();
        $commande = $this->creerCommande($client, $vendeur, Commande::STATUT_RECUE);

        Sanctum::actingAs($clientUser);

        $this->patchJson("/api/commandes/{$commande->id}/annuler")
            ->assertOk()
            ->assertJsonPath('commande.statut', Commande::STATUT_ANNULEE);

        $this->patchJson("/api/commandes/{$commande->id}/annuler")
            ->assertUnprocessable()
            ->assertJsonPath('code', 'ANNULATION_CLIENT_IMPOSSIBLE');
    }

    public function test_client_ne_peut_annuler_ni_commande_etrangere_ni_commande_en_preparation(): void
    {
        [$clientUser, $client] = $this->creerClient();
        [, $autreClient] = $this->creerClient();
        $vendeur = $this->creerVendeur();
        $commandeEnPreparation = $this->creerCommande($client, $vendeur, Commande::STATUT_PREPARATION);
        $commandeEtrangere = $this->creerCommande($autreClient, $vendeur, Commande::STATUT_RECUE);

        Sanctum::actingAs($clientUser);

        $this->patchJson("/api/commandes/{$commandeEnPreparation->id}/annuler")
            ->assertUnprocessable()
            ->assertJsonPath('code', 'ANNULATION_CLIENT_IMPOSSIBLE');

        $this->patchJson("/api/commandes/{$commandeEtrangere->id}/annuler")
            ->assertForbidden();

        $this->assertDatabaseHas('commandes', [
            'id' => $commandeEtrangere->id,
            'statut' => Commande::STATUT_RECUE,
        ]);
    }

    public function test_vendeur_affecte_peut_annuler_une_commande_non_terminale(): void
    {
        [, $client] = $this->creerClient();
        [$vendeurUser, $vendeur] = $this->creerVendeurAvecUtilisateur();
        $commande = $this->creerCommande($client, $vendeur, Commande::STATUT_EN_LIVRAISON);

        Sanctum::actingAs($vendeurUser);

        $this->patchJson("/api/vendeur/commandes/{$commande->id}/statut", [
            'statut' => Commande::STATUT_ANNULEE,
        ])
            ->assertOk()
            ->assertJsonPath('commande.statut', Commande::STATUT_ANNULEE);

        $this->patchJson("/api/vendeur/commandes/{$commande->id}/statut", [
            'statut' => Commande::STATUT_RECUE,
        ])->assertUnprocessable();
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
