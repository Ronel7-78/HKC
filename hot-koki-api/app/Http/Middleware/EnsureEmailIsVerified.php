<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureEmailIsVerified
{
    public function handle(Request $request, Closure $next): Response
    {
        if (! config('email_auth.verification_enabled')) {
            return $next($request);
        }

        $user = $request->user();

        if (! $user?->email_verified_at) {
            $user?->currentAccessToken()?->delete();

            return response()->json([
                'message' => 'Votre adresse email doit être vérifiée pour accéder à votre compte.',
                'code' => 'EMAIL_NON_VERIFIE',
                'email' => $user?->email,
                'verification_requise' => true,
            ], 403);
        }

        return $next($request);
    }
}
