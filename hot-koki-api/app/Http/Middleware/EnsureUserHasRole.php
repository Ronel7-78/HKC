<?php

// Ce middleware protege les routes reservees a un type d'utilisateur.

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureUserHasRole
{
    /**
     * Autorise la requete uniquement si le role de l'utilisateur est attendu.
     *
     * Plusieurs roles peuvent etre fournis au middleware si une route doit etre
     * partagee plus tard, par exemple : role:client,vendeur.
     */
    public function handle(Request $request, Closure $next, string ...$roles): Response
    {
        // L'authentification est normalement verifiee avant ce middleware.
        $user = $request->user();

        if (! $user || ! in_array($user->role, $roles, true)) {
            return response()->json([
                'message' => 'Vous n\'avez pas le role requis pour acceder a cette ressource',
            ], 403);
        }

        return $next($request);
    }
}
