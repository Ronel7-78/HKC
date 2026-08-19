<?php

namespace Tests\Feature;

use App\Models\Admin;
use App\Models\Client;
use App\Models\Commande;
use App\Models\Paiement;
use App\Models\User;
use App\Models\Vendeur;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
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

    public function test_admin_consulte_les_revenus_par_periode_et_par_vendeur(): void
    {
        Carbon::setTestNow('2026-08-19 12:00:00');
        $admin = User::factory()->create(['role' => 'admin']);
        $client = Client::create([
            'user_id' => User::factory()->create(['role' => 'client'])->id,
            'nom' => 'Cliente rapports',
        ]);
        $vendeur = Vendeur::create([
            'user_id' => User::factory()->create(['role' => 'vendeur'])->id,
            'nom_boutique' => 'Koki Finance',
        ]);

        $this->createPayment($client, $vendeur, 1000, now());
        $this->createPayment($client, $vendeur, 2000, now()->subDays(2));
        $this->createPayment($client, $vendeur, 3000, now()->subDays(10));
        $this->createPayment($client, $vendeur, 9000, now(), Paiement::STATUT_ECHOUE);

        Sanctum::actingAs($admin);
        $this->getJson('/api/admin/dashboard')
            ->assertOk()
            ->assertJsonPath('revenus.jour', 1000)
            ->assertJsonPath('revenus.semaine', 3000)
            ->assertJsonPath('revenus.mois', 6000)
            ->assertJsonPath('revenus.total', 6000)
            ->assertJsonPath('revenus.paiements_reussis', 3)
            ->assertJsonPath('revenus_par_vendeur.0.nom_boutique', 'Koki Finance')
            ->assertJsonPath('revenus_par_vendeur.0.semaine', 3000)
            ->assertJsonPath('revenus_par_vendeur.0.mois', 6000);
    }

    private function createPayment(
        Client $client,
        Vendeur $vendeur,
        int $amount,
        Carbon $confirmedAt,
        string $status = Paiement::STATUT_REUSSI,
    ): void {
        $commande = Commande::create([
            'client_id' => $client->id,
            'vendeur_id' => $vendeur->id,
            'statut' => Commande::STATUT_RECUE,
            'adresse_livraison' => 'Douala',
            'latitude_client' => 4.05,
            'longitude_client' => 9.70,
            'sous_total' => $amount,
            'frais_livraison' => 0,
            'total' => $amount,
        ]);
        $commande->paiements()->create([
            'fournisseur' => Paiement::FOURNISSEUR_MTN_MOMO,
            'telephone' => '237670000000',
            'montant' => $amount,
            'devise' => 'XAF',
            'statut' => $status,
            'confirme_le' => $confirmedAt,
        ]);
    }
}
