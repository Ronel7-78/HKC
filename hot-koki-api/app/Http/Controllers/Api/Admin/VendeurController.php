<?php

// Ce controleur permet a l'administrateur de gerer les vendeurs.

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\Vendeur;
use App\Services\NotificationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rule;

class VendeurController extends Controller
{
    /**
     * Liste tous les vendeurs actifs ou suspendus.
     */
    public function index()
    {
        return response()->json(
            Vendeur::with('user')->latest()->get(),
        );
    }

    /**
     * Cree le compte utilisateur et le profil du vendeur en une transaction.
     */
    public function store(Request $request)
    {
        // Les identifiants temporaires sont definis par l'administrateur.
        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:255',
            'email' => 'required|string|email|max:255|unique:users,email',
            'telephone' => 'required|string|max:20|unique:users,telephone',
            'password' => 'required|string|min:8|max:128|confirmed',
            'nom_boutique' => 'required|string|max:255',
            'description' => 'nullable|string|max:2000',
            'adresse_texte' => 'nullable|string|max:255',
            'latitude' => 'nullable|numeric',
            'longitude' => 'nullable|numeric',
        ], $this->messages());

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        // La transaction evite de conserver un utilisateur sans profil vendeur.
        $vendeur = DB::transaction(function () use ($request) {
            $user = User::make([
                'name' => $request->name,
                'email' => mb_strtolower(trim($request->email)),
                'telephone' => $request->telephone,
                'password' => Hash::make($request->password),
            ]);
            $user->forceFill([
                'role' => 'vendeur',
                'email_verified_at' => now(),
            ])->save();

            return Vendeur::create([
                'user_id' => $user->id,
                'nom_boutique' => $request->nom_boutique,
                'description' => $request->description,
                'adresse_texte' => $request->adresse_texte,
                'latitude' => $request->latitude,
                'longitude' => $request->longitude,
            ]);
        });

        NotificationService::envoyer(
            $vendeur->user,
            'compte_vendeur_cree',
            'Bienvenue sur Hot Koki',
            'Votre espace vendeur a été créé. Complétez votre catalogue et votre disponibilité.'
        );

        return response()->json([
            'message' => 'Vendeur créé avec succès',
            'vendeur' => $vendeur->load('user'),
        ], 201);
    }

    /**
     * Affiche un vendeur et ses informations de connexion, sans son mot de passe.
     */
    public function show(Vendeur $vendeur)
    {
        return response()->json($vendeur->load('user'));
    }

    /**
     * Permet a l'administrateur de corriger les informations et le statut du vendeur.
     */
    public function update(Request $request, Vendeur $vendeur)
    {
        $ancienStatut = $vendeur->statut_compte;
        $validator = Validator::make($request->all(), [
            'name' => 'sometimes|string|max:255',
            'email' => [
                'sometimes',
                'string',
                'email',
                'max:20',
                Rule::unique('users', 'email')->ignore($vendeur->user_id),
            ],
            'telephone' => [
                'sometimes',
                'string',
                'max:255',
                Rule::unique('users', 'telephone')->ignore($vendeur->user_id),
            ],
            'nom_boutique' => 'sometimes|string|max:255',
            'description' => 'sometimes|nullable|string|max:2000',
            'adresse_texte' => 'sometimes|nullable|string|max:255',
            'latitude' => 'sometimes|nullable|numeric',
            'longitude' => 'sometimes|nullable|numeric',
            'statut_compte' => 'sometimes|in:actif,suspendu',
        ], $this->messages());

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        DB::transaction(function () use ($request, $vendeur) {
            // Les informations de connexion sont conservees dans users.
            $vendeur->user->update($request->only([
                'name',
                'email',
                'telephone',
            ]));

            // Les informations commerciales sont conservees dans vendeurs.
            $vendeur->update($request->only([
                'nom_boutique',
                'description',
                'adresse_texte',
                'latitude',
                'longitude',
                'statut_compte',
            ]));

            // Une suspension prend effet immediatement sur les sessions existantes.
            if ($request->statut_compte === 'suspendu') {
                $vendeur->user->tokens()->delete();
            }
        });

        if ($request->filled('statut_compte') && $request->statut_compte !== $ancienStatut) {
            NotificationService::envoyer(
                $vendeur->user,
                'statut_compte',
                'Statut du compte vendeur',
                $request->statut_compte === 'actif'
                    ? 'Votre compte vendeur est maintenant actif.'
                    : 'Votre compte vendeur a été suspendu. Contactez l’administration pour plus d’informations.',
                ['statut' => $request->statut_compte]
            );
        }

        return response()->json([
            'message' => 'Vendeur mis à jour',
            'vendeur' => $vendeur->fresh()->load('user'),
        ]);
    }

    /**
     * Supprime logiquement le vendeur et bloque immediatement ses acces.
     */
    public function destroy(Vendeur $vendeur)
    {
        DB::transaction(function () use ($vendeur) {
            $user = $vendeur->user;

            // Les tokens sont revoques avant la suppression logique du compte.
            $user->tokens()->delete();
            $vendeur->delete();
            $user->delete();
        });

        return response()->json(['message' => 'Vendeur supprimé']);
    }

    private function messages(): array
    {
        return [
            'required' => 'Le champ :attribute est obligatoire.',
            'email.email' => 'L’adresse email n’est pas valide.',
            'email.unique' => 'Cette adresse email est déjà utilisée.',
            'telephone.unique' => 'Ce numéro de téléphone est déjà utilisé.',
            'password.min' => 'Le mot de passe doit contenir au moins 8 caractères.',
            'password.confirmed' => 'La confirmation du mot de passe ne correspond pas.',
        ];
    }
}
