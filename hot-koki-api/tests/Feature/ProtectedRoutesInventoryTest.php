<?php

namespace Tests\Feature;

use Illuminate\Routing\Route;
use Illuminate\Support\Facades\Route as RouteFacade;
use Tests\TestCase;

class ProtectedRoutesInventoryTest extends TestCase
{
    private const PUBLIC_API_ROUTES = [
        'api/accueil',
        'api/catalogue',
        'api/email/resend',
        'api/email/verify',
        'api/forgot-password',
        'api/health',
        'api/login',
        'api/register',
        'api/reset-password',
        'api/webhooks/mtn-momo/{transactionHash}',
        'api/webhooks/orange-money',
    ];

    public function test_toute_route_api_non_publique_exige_sanctum(): void
    {
        foreach ($this->apiRoutes() as $route) {
            if (in_array($route->uri(), self::PUBLIC_API_ROUTES, true)) {
                continue;
            }

            $this->assertMiddleware($route, 'auth:sanctum');
        }
    }

    public function test_les_routes_admin_client_et_vendeur_exigent_leur_role(): void
    {
        foreach ($this->apiRoutes() as $route) {
            $uri = $route->uri();
            if (str_starts_with($uri, 'api/admin/')) {
                $this->assertMiddleware($route, 'isAdmin');
            }
            if (str_starts_with($uri, 'api/client/')) {
                $this->assertMiddleware($route, 'role:client');
            }
            if (str_starts_with($uri, 'api/vendeur/')) {
                $this->assertMiddleware($route, 'role:vendeur');
            }
        }
    }

    /** @return array<int, Route> */
    private function apiRoutes(): array
    {
        return array_values(array_filter(
            RouteFacade::getRoutes()->getRoutes(),
            fn (Route $route) => str_starts_with($route->uri(), 'api/'),
        ));
    }

    private function assertMiddleware(Route $route, string $expected): void
    {
        $this->assertContains(
            $expected,
            $route->gatherMiddleware(),
            "La route {$route->uri()} doit utiliser le middleware {$expected}.",
        );
    }
}
