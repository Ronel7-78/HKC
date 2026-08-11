<?php

// Ces tests verifient l'isolation des espaces client, vendeur et admin.

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class RoleAuthorizationTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Une API sans token doit retourner 401 meme sans en-tete Accept JSON.
     */
    public function test_api_returns_unauthorized_instead_of_redirecting_to_login(): void
    {
        $this->get('/api/client/profile')
            ->assertUnauthorized()
            ->assertJsonPath('message', 'Unauthenticated.');
    }

    /**
     * Un client ne doit pas pouvoir acceder a l'espace vendeur.
     */
    public function test_client_cannot_access_vendeur_routes(): void
    {
        $client = User::factory()->create(['role' => 'client']);
        Sanctum::actingAs($client);

        $this->getJson('/api/vendeur/profile')
            ->assertForbidden();
    }

    /**
     * Un vendeur ne doit pas pouvoir acceder a l'espace client.
     */
    public function test_vendeur_cannot_access_client_routes(): void
    {
        $vendeur = User::factory()->create(['role' => 'vendeur']);
        Sanctum::actingAs($vendeur);

        $this->getJson('/api/client/profile')
            ->assertForbidden();
    }

    /**
     * Les routes de commande sont reservees aux clients.
     */
    public function test_vendeur_cannot_access_commande_routes(): void
    {
        $vendeur = User::factory()->create(['role' => 'vendeur']);
        Sanctum::actingAs($vendeur);

        $this->getJson('/api/commandes')
            ->assertForbidden();
    }

    /**
     * Le middleware laisse passer un utilisateur ayant le bon role.
     */
    public function test_client_can_reach_client_routes(): void
    {
        $client = User::factory()->create(['role' => 'client']);
        Sanctum::actingAs($client);

        // Le profil n'existe pas dans ce test : le controleur repond donc 404,
        // ce qui confirme que le middleware a bien autorise la requete.
        $this->getJson('/api/client/profile')
            ->assertNotFound();
    }
}
