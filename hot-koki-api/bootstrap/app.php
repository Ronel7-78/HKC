<?php

use App\Http\Middleware\EnsureUserHasRole;
use App\Http\Middleware\IsAdmin;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Exceptions\HttpResponseException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    // Middlewares utilises pour proteger les routes selon le role.
    ->withMiddleware(function (Middleware $middleware): void {
        // Plafond global appliqué à toutes les routes API. Les routes sensibles
        // ajoutent des limites métier plus strictes dans routes/api.php.
        $middleware->throttleApi('api-global');

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

        $exceptions->render(function (Throwable $exception, Request $request) {
            if (! $request->is('api/*')) {
                return null;
            }

            if ($exception instanceof ValidationException
                || $exception instanceof AuthenticationException
                || $exception instanceof AuthorizationException
                || $exception instanceof HttpResponseException) {
                return null;
            }

            $status = $exception instanceof ModelNotFoundException
                ? 404
                : ($exception instanceof HttpExceptionInterface
                ? $exception->getStatusCode()
                : 500);

            if ($status === 404) {
                return response()->json([
                    'message' => 'Ressource introuvable.',
                    'code' => 'RESSOURCE_INTROUVABLE',
                ], 404);
            }

            if ($status === 405) {
                return response()->json([
                    'message' => 'Méthode non autorisée.',
                    'code' => 'METHODE_NON_AUTORISEE',
                ], 405);
            }

            if ($status < 500) {
                return null;
            }

            $incident = bin2hex(random_bytes(8));
            Log::error('Erreur API inattendue', [
                'incident_id' => $incident,
                'route' => $request->route()?->uri(),
                'method' => $request->method(),
                'user_id' => $request->user()?->getAuthIdentifier(),
                'ip' => $request->ip(),
                'exception' => $exception,
            ]);

            return response()->json([
                'message' => 'Une erreur interne est survenue. Réessayez plus tard.',
                'code' => 'ERREUR_INTERNE',
                'incident_id' => $incident,
            ], $status);
        });
    })->create();
