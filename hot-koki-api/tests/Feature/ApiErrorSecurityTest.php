<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\Route;
use RuntimeException;
use Tests\TestCase;

class ApiErrorSecurityTest extends TestCase
{
    public function test_une_exception_interne_ne_revele_aucun_detail_technique(): void
    {
        Route::middleware('api')->get('/api/_test/erreur-interne', function () {
            throw new RuntimeException('SQLSTATE[HY000] mot-de-passe-interne /var/www/secret.php');
        });

        $response = $this->getJson('/api/_test/erreur-interne')
            ->assertInternalServerError()
            ->assertJsonPath('code', 'ERREUR_INTERNE')
            ->assertJsonStructure(['message', 'code', 'incident_id']);

        $contenu = $response->getContent();
        $this->assertStringNotContainsString('SQLSTATE', $contenu);
        $this->assertStringNotContainsString('mot-de-passe-interne', $contenu);
        $this->assertStringNotContainsString('/var/www', $contenu);
        $this->assertMatchesRegularExpression('/^[a-f0-9]{16}$/', $response->json('incident_id'));
    }

    public function test_une_route_inconnue_ne_revele_pas_les_details_du_routeur(): void
    {
        $this->getJson('/api/route-totalement-inexistante')
            ->assertNotFound()
            ->assertExactJson([
                'message' => 'Ressource introuvable.',
                'code' => 'RESSOURCE_INTROUVABLE',
            ]);
    }
}
