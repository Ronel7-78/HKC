<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\EmailAuthCode;
use App\Models\User;
use App\Services\EmailCodeService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class EmailAuthController extends Controller
{
    public function verify(Request $request, EmailCodeService $codes)
    {
        $validated = $request->validate([
            'email' => ['required', 'email'],
            'code' => ['required', 'digits:6'],
        ], $this->messages());

        $user = User::where('email', mb_strtolower($validated['email']))->first();
        if (! $user) {
            return response()->json(['message' => 'Code invalide ou expiré.'], 422);
        }

        $codes->consume($user, EmailAuthCode::PURPOSE_VERIFY_EMAIL, $validated['code']);
        $user->forceFill(['email_verified_at' => now()])->save();
        $user->tokens()->delete();
        $token = $user->createToken('auth_token')->plainTextToken;

        return response()->json([
            'message' => 'Adresse email vérifiée avec succès.',
            'user' => $user,
            'token' => $token,
        ]);
    }

    public function resend(Request $request, EmailCodeService $codes)
    {
        $validated = $request->validate(['email' => ['required', 'email']], $this->messages());
        $user = User::where('email', mb_strtolower($validated['email']))->first();

        if ($user && ! $user->email_verified_at && ! $user->isAdmin()) {
            $codes->issue($user, EmailAuthCode::PURPOSE_VERIFY_EMAIL);
        }

        return response()->json(['message' => 'Si ce compte nécessite une vérification, un code vient d’être envoyé.']);
    }

    public function forgotPassword(Request $request, EmailCodeService $codes)
    {
        $validated = $request->validate(['email' => ['required', 'email']], $this->messages());
        $user = User::where('email', mb_strtolower($validated['email']))->first();

        if ($user) {
            try {
                $codes->issue($user, EmailAuthCode::PURPOSE_RESET_PASSWORD);
            } catch (ValidationException) {
                // La réponse reste volontairement identique pour ne pas
                // permettre de déduire si une adresse possède un compte.
            }
        }

        return response()->json([
            'message' => 'Si cette adresse correspond à un compte, un code de réinitialisation a été envoyé.',
        ], 202);
    }

    public function resetPassword(Request $request, EmailCodeService $codes)
    {
        $validated = $request->validate([
            'email' => ['required', 'email'],
            'code' => ['required', 'digits:6'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
        ], $this->messages());

        $user = User::where('email', mb_strtolower($validated['email']))->first();
        if (! $user) {
            return response()->json(['message' => 'Code invalide ou expiré.'], 422);
        }

        $codes->consume($user, EmailAuthCode::PURPOSE_RESET_PASSWORD, $validated['code']);
        $user->forceFill([
            'password' => Hash::make($validated['password']),
            'email_verified_at' => $user->email_verified_at ?? now(),
        ])->save();
        $user->tokens()->delete();

        return response()->json([
            'message' => 'Mot de passe réinitialisé. Vous pouvez maintenant vous connecter.',
        ]);
    }

    private function messages(): array
    {
        return [
            'email.required' => 'L’adresse email est obligatoire.',
            'email.email' => 'L’adresse email n’est pas valide.',
            'code.required' => 'Le code est obligatoire.',
            'code.digits' => 'Le code doit contenir exactement 6 chiffres.',
            'password.required' => 'Le nouveau mot de passe est obligatoire.',
            'password.min' => 'Le mot de passe doit contenir au moins 8 caractères.',
            'password.confirmed' => 'La confirmation du mot de passe ne correspond pas.',
        ];
    }
}
