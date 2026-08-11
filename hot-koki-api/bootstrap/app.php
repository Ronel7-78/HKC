<?php

use App\Http\Middleware\EnsureUserHasRole;
use App\Http\Middleware\IsAdmin;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    // Middlewares utilises pour proteger les routes selon le role.
    ->withMiddleware(function (Middleware $middleware): void {
        // Une requete API non authentifiee doit recevoir une erreur JSON 401.
        // La redirection vers une page de connexion reste reservee aux routes web.
        $middleware->redirectGuestsTo(
            fn (Request $request) => $request->is('api/*') ? null : route('login'),
        );

        $middleware->alias([
            // Protege les routes d'administration deja existantes.
            'isAdmin' => IsAdmin::class,

            // Protege les espaces client et vendeur avec le meme middleware.
            'role' => EnsureUserHasRole::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        // Retourne toujours les erreurs de l'API au format JSON.
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request) => $request->is('api/*'),
        );
    })->create();
