<?php

// app/Http/Controllers/Api/AuthController.php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Client;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;

class AuthController extends Controller
{
    // Inscription publique reservee exclusivement aux clients.
    public function register(Request $request)
    {
        // Le role n'est pas accepte depuis la requete pour eviter la creation
        // publique d'un compte vendeur ou administrateur.
        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:255',
            'email' => 'required|string|email|max:255|unique:users',
            'telephone' => 'required|string|unique:users',
            'password' => 'required|string|min:8|confirmed',
            'adresse_texte' => 'required|string|max:255',
            'latitude' => 'required|numeric|between:-90,90',
            'longitude' => 'required|numeric|between:-180,180',
        ], [
            'name.required' => 'Le nom est obligatoire.',
            'email.required' => 'L’adresse email est obligatoire.',
            'email.email' => 'L’adresse email n’est pas valide.',
            'email.unique' => 'Cette adresse email est déjà utilisée.',
            'telephone.required' => 'Le numéro de téléphone est obligatoire.',
            'telephone.unique' => 'Ce numéro de téléphone est déjà utilisé.',
            'password.required' => 'Le mot de passe est obligatoire.',
            'password.min' => 'Le mot de passe doit contenir au moins 8 caractères.',
            'password.confirmed' => 'La confirmation du mot de passe ne correspond pas.',
            'adresse_texte.required' => 'La localisation est obligatoire.',
            'latitude.required' => 'La latitude est obligatoire.',
            'longitude.required' => 'La longitude est obligatoire.',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        // Un compte cree par cette route est toujours un client.
        $user = User::create([
            'name' => $request->name,
            'email' => $request->email,
            'telephone' => $request->telephone,
            'password' => Hash::make($request->password),
            'role' => 'client',
        ]);

        // Le profil client est cree automatiquement avec le compte utilisateur.
        Client::create([
            'user_id' => $user->id,
            'nom' => $request->name,
            'adresse_texte' => $request->adresse_texte,
            'latitude' => $request->latitude,
            'longitude' => $request->longitude,
        ]);

        $token = $user->createToken('auth_token')->plainTextToken;

        return response()->json([
            'message' => 'Compte créé avec succès',
            'user' => $user->load('client'),
            'token' => $token,
        ], 201);
    }

    // Connexion
    public function login(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'email' => 'required|email',
            'password' => 'required',
        ], [
            'email.required' => 'L’adresse email est obligatoire.',
            'email.email' => 'L’adresse email n’est pas valide.',
            'password.required' => 'Le mot de passe est obligatoire.',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $user = User::where('email', $request->email)->first();

        if (! $user || ! Hash::check($request->password, $user->password)) {
            return response()->json(['message' => 'Identifiants incorrects'], 401);
        }

        if (! $this->profilMetierExiste($user)) {
            $user->tokens()->delete();

            return response()->json([
                'message' => 'Ce compte est incomplet : le profil associé est introuvable. Contactez un administrateur.',
                'code' => 'PROFIL_METIER_INTROUVABLE',
            ], 409);
        }

        // Un vendeur suspendu conserve son compte, mais ne peut plus se connecter.
        if ($user->isVendeur() && $user->vendeur?->statut_compte === 'suspendu') {
            return response()->json(['message' => 'Compte vendeur suspendu'], 403);
        }

        $token = $user->createToken('auth_token')->plainTextToken;

        return response()->json([
            'message' => 'Connexion réussie',
            'user' => $user,
            'token' => $token,
        ]);
    }

    // Déconnexion
    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => 'Déconnexion réussie']);
    }

    // Récupérer l'utilisateur connecté (utile pour Flutter au démarrage de l'app)
    public function me(Request $request)
    {
        $user = $request->user();

        if (! $this->profilMetierExiste($user)) {
            $user->currentAccessToken()?->delete();

            return response()->json([
                'message' => 'La session a été fermée car le profil associé à ce compte est introuvable.',
                'code' => 'PROFIL_METIER_INTROUVABLE',
            ], 409);
        }

        return response()->json($user);
    }

    private function profilMetierExiste(User $user): bool
    {
        return match ($user->role) {
            'client' => $user->client()->exists(),
            'vendeur' => $user->vendeur()->exists(),
            'admin' => $user->admin()->exists(),
            default => false,
        };
    }
}
