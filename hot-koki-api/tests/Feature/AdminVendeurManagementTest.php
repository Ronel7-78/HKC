<?php

// Ces tests couvrent la creation, la suspension et la suppression des vendeurs.

namespace Tests\Feature;

use App\Models\User;
use App\Models\Vendeur;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Notification;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminVendeurManagementTest extends TestCase
{
    use RefreshDatabase;

    /**
     * L'inscription publique doit toujours creer un client.
     */
    public function test_public_registration_cannot_create_a_vendeur_or_an_admin(): void
    {
        $response = $this->postJson('/api/register', [
            'name' => 'Client public',
            'email' => 'client@example.com',
            'telephone' => '690000001',
            'password' => 'password',
            'password_confirmation' => 'password',
            'adresse_texte' => 'Mokolo, Bertoua',
            'latitude' => 4.5763,
            'longitude' => 13.6845,
            'role' => 'admin',
            'conditions_acceptees' => true,
        ]);

        $response->assertCreated()
            ->assertJsonPath('user.role', 'client');

        $this->assertDatabaseHas('clients', ['nom' => 'Client public']);
        $this->assertDatabaseMissing('admins', ['nom' => 'Client public']);
    }

    /**
     * Seul l'administrateur peut creer le compte et le profil d'un vendeur.
     */
    public function test_admin_can_create_a_vendeur(): void
    {
        Notification::fake();
        Sanctum::actingAs($this->admin());

        $response = $this->postJson('/api/admin/vendeurs', $this->vendeurData());

        $response->assertCreated()
            ->assertJsonPath('vendeur.nom_boutique', 'Koki du quartier')
            ->assertJsonPath('vendeur.user.role', 'vendeur')
            ->assertJsonPath('verification_requise', true);

        $this->assertDatabaseHas('users', [
            'email' => 'vendeur@example.com',
            'role' => 'vendeur',
        ]);
        $this->assertDatabaseHas('vendeurs', ['nom_boutique' => 'Koki du quartier']);
        $this->assertNull(User::where('email', 'vendeur@example.com')->firstOrFail()->email_verified_at);
    }

    /**
     * Un client ne doit jamais pouvoir creer un vendeur.
     */
    public function test_client_cannot_create_a_vendeur(): void
    {
        Sanctum::actingAs(User::factory()->create(['role' => 'client']));

        $this->postJson('/api/admin/vendeurs', $this->vendeurData())
            ->assertForbidden();
    }

    /**
     * La suppression conserve les donnees et revoque les tokens du vendeur.
     */
    public function test_admin_soft_deletes_vendeur_and_revokes_tokens(): void
    {
        $admin = $this->admin();
        $user = User::factory()->create(['role' => 'vendeur']);
        $vendeur = Vendeur::create([
            'user_id' => $user->id,
            'nom_boutique' => 'Koki à conserver',
        ]);
        $user->createToken('auth_token');

        Sanctum::actingAs($admin);

        $this->deleteJson("/api/admin/vendeurs/{$vendeur->public_id}")
            ->assertOk();

        $this->assertSoftDeleted('users', ['id' => $user->id]);
        $this->assertSoftDeleted('vendeurs', ['id' => $vendeur->id]);
        $this->assertDatabaseMissing('personal_access_tokens', [
            'tokenable_type' => User::class,
            'tokenable_id' => $user->id,
        ]);
    }

    /**
     * Un vendeur suspendu ne peut plus ouvrir une nouvelle session.
     */
    public function test_suspended_vendeur_cannot_login(): void
    {
        $user = User::factory()->create([
            'email' => 'suspendu@example.com',
            'password' => 'password',
            'role' => 'vendeur',
        ]);
        Vendeur::create([
            'user_id' => $user->id,
            'nom_boutique' => 'Boutique suspendue',
            'statut_compte' => 'suspendu',
        ]);

        $this->postJson('/api/login', [
            'email' => 'suspendu@example.com',
            'password' => 'password',
            'conditions_acceptees' => true,
        ])->assertForbidden();
    }

    /**
     * Donnees valides reutilisees par les tests de creation.
     *
     * @return array<string, string>
     */
    private function vendeurData(): array
    {
        return [
            'name' => 'Vendeur Test',
            'email' => 'vendeur@example.com',
            'telephone' => '690000002',
            'password' => 'password',
            'password_confirmation' => 'password',
            'nom_boutique' => 'Koki du quartier',
        ];
    }

    private function admin(): User
    {
        $admin = User::factory()->create(['role' => 'admin']);
        $admin->admin()->create(['nom' => 'Admin', 'prenom' => 'Test']);

        return $admin;
    }
}
