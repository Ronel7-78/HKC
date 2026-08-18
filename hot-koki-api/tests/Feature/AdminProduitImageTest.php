<?php

namespace Tests\Feature;

use App\Models\Produit;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminProduitImageTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_peut_ajouter_remplacer_et_retirer_la_photo_du_produit(): void
    {
        Storage::fake('public');
        Sanctum::actingAs(User::factory()->create(['role' => 'admin']));

        $creation = $this->post('/api/admin/produits', [
            'nom' => 'Koki royal',
            'prix' => 2500,
            'photo' => $this->fakePng('koki.png'),
        ], ['Accept' => 'application/json']);

        $creation->assertCreated();
        $produit = Produit::findOrFail($creation->json('produit.id'));
        $premierePhoto = str_replace('storage/', '', $produit->photo);
        Storage::disk('public')->assertExists($premierePhoto);

        $this->post("/api/admin/produits/{$produit->id}", [
            '_method' => 'PUT',
            'photo' => $this->fakePng('nouveau-koki.png'),
        ], ['Accept' => 'application/json'])->assertOk();

        $produit->refresh();
        Storage::disk('public')->assertMissing($premierePhoto);
        Storage::disk('public')->assertExists(str_replace('storage/', '', $produit->photo));

        $dernierePhoto = str_replace('storage/', '', $produit->photo);
        $this->putJson("/api/admin/produits/{$produit->id}", [
            'supprimer_photo' => true,
        ])->assertOk()->assertJsonPath('produit.photo', null);
        Storage::disk('public')->assertMissing($dernierePhoto);
    }

    private function fakePng(string $name): UploadedFile
    {
        return UploadedFile::fake()->createWithContent(
            $name,
            base64_decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='),
        );
    }
}
