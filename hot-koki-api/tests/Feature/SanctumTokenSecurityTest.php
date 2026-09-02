<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SanctumTokenSecurityTest extends TestCase
{
    use RefreshDatabase;

    public function test_le_token_est_stocke_hache_et_prefixe(): void
    {
        $user = User::factory()->create();
        $created = $user->createToken('test');
        [, $secret] = explode('|', $created->plainTextToken, 2);

        $this->assertStringStartsWith('hotkoki_', $secret);
        $this->assertNotSame($secret, $created->accessToken->token);
        $this->assertSame(hash('sha256', $secret), $created->accessToken->token);
    }

    public function test_un_token_expire_ne_peut_pas_acceder_a_une_route_protegee(): void
    {
        $user = User::factory()->create();
        $token = $user->createToken('expire', ['*'], now()->subMinute())->plainTextToken;

        $this->withToken($token)->getJson('/api/me')->assertUnauthorized();
    }
}
