<?php

namespace Tests\Feature;

use App\Models\Admin;
use App\Models\User;
use App\Models\Vendeur;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminDashboardTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_consulte_son_tableau_de_bord_et_son_profil(): void
    {
        $user = User::factory()->create(['role' => 'admin']);
        Admin::create(['user_id' => $user->id, 'nom' => 'Administrateur']);
        Vendeur::create([
            'user_id' => User::factory()->create(['role' => 'vendeur'])->id,
            'nom_boutique' => 'Koki Admin Test',
            'statut_compte' => 'actif',
        ]);
        Sanctum::actingAs($user);

        $this->getJson('/api/admin/dashboard')
            ->assertOk()
            ->assertJsonPath('statistiques.vendeurs_actifs', 1)
            ->assertJsonCount(1, 'vendeurs_recents');

        $this->getJson('/api/admin/profile')
            ->assertOk()
            ->assertJsonPath('user.id', $user->id)
            ->assertJsonPath('admin.nom', 'Administrateur');
    }

    public function test_client_ne_peut_pas_consulter_le_tableau_admin(): void
    {
        Sanctum::actingAs(User::factory()->create(['role' => 'client']));

        $this->getJson('/api/admin/dashboard')->assertForbidden();
    }
}
