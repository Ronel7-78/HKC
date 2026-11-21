<?php

namespace Tests\Feature;

use App\Models\Admin;
use App\Models\Avis;
use App\Models\Client;
use App\Models\Commande;
use App\Models\User;
use App\Models\Vendeur;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AvisModerationTest extends TestCase
{
    use RefreshDatabase;

    public function test_un_utilisateur_peut_signaler_une_seule_fois_un_avis_public(): void
    {
        [$avis, $auteur] = $this->avisPublic();
        $signaleur = User::factory()->create(['role' => 'client']);
        Client::create(['user_id' => $signaleur->id, 'nom' => 'Signaleur']);
        Sanctum::actingAs($signaleur);

        $this->postJson('/api/avis-publics/'.$avis->id.'/signaler', [
            'motif' => 'spam',
            'details' => 'Ce contenu ne respecte pas les règles.',
        ])->assertCreated()->assertJsonPath('signalement.motif', 'spam');

        $this->postJson('/api/avis-publics/'.$avis->id.'/signaler', [
            'motif' => 'spam',
        ])->assertOk()->assertJsonPath('message', 'Vous avez déjà signalé cet avis. Il sera examiné par notre équipe.');

        $this->assertDatabaseCount('avis_signalements', 1);

        Sanctum::actingAs($auteur);
        $this->postJson('/api/avis-publics/'.$avis->id.'/signaler', ['motif' => 'autre'])
            ->assertUnprocessable();
    }

    public function test_admin_peut_masquer_un_avis_sans_le_supprimer_et_ferme_le_signalement(): void
    {
        [$avis] = $this->avisPublic();
        $signaleur = User::factory()->create(['role' => 'client']);
        Client::create(['user_id' => $signaleur->id, 'nom' => 'Signaleur']);
        Sanctum::actingAs($signaleur);
        $this->postJson('/api/avis-publics/'.$avis->id.'/signaler', ['motif' => 'harcelement'])
            ->assertCreated();

        $adminUser = User::factory()->create(['role' => 'admin']);
        Admin::create(['user_id' => $adminUser->id, 'nom' => 'Admin']);
        Sanctum::actingAs($adminUser);

        $this->getJson('/api/admin/avis/signalements')
            ->assertOk()
            ->assertJsonPath('data.0.avis.id', $avis->id);

        $this->patchJson('/api/admin/avis/'.$avis->id.'/moderation', [
            'action' => 'masquer',
            'note_moderation' => 'Contenu inapproprié confirmé.',
        ])->assertOk()->assertJsonPath('message', 'Avis masqué et signalements traités.')
            ->assertJsonPath('avis.motif_masquage', 'Contenu inapproprié confirmé.')
            ->assertJsonStructure(['avis' => ['masque_le']]);

        $this->assertDatabaseHas('avis', ['id' => $avis->id]);
        $this->assertDatabaseMissing('avis_signalements', ['avis_id' => $avis->id, 'statut' => 'ouvert']);
        $this->getJson('/api/avis-publics')->assertOk()->assertJsonMissing(['id' => $avis->id]);
    }

    /** @return array{Avis, User} */
    private function avisPublic(): array
    {
        $auteur = User::factory()->create(['role' => 'client']);
        $client = Client::create(['user_id' => $auteur->id, 'nom' => 'Auteure']);
        $vendeur = Vendeur::create([
            'user_id' => User::factory()->create(['role' => 'vendeur'])->id,
            'nom_boutique' => 'Chez Hot Koki',
        ]);
        $commande = Commande::create([
            'client_id' => $client->id,
            'vendeur_id' => $vendeur->id,
            'statut' => Commande::STATUT_LIVREE,
            'adresse_livraison' => 'Yaoundé',
            'latitude_client' => 3.87,
            'longitude_client' => 11.52,
            'sous_total' => 1000,
            'frais_livraison' => 0,
            'total' => 1000,
        ]);

        return [Avis::create([
            'commande_id' => $commande->id,
            'client_id' => $client->id,
            'vendeur_id' => $vendeur->id,
            'note' => 1,
            'commentaire' => 'Texte à modérer.',
        ]), $auteur];
    }
}
