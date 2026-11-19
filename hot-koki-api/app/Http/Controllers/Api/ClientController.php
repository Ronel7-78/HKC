<?php

// app/Http/Controllers/Api/ClientController.php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Commande;
use App\Models\EmailAuthCode;
use App\Models\Paiement;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class ClientController extends Controller
{
    // Voir mon profil client
    public function show(Request $request)
    {
        $client = $request->user()->client;

        if (! $client) {
            return response()->json(['message' => 'Profil client introuvable'], 404);
        }

        return response()->json([
            'client' => $client,
            'user' => $request->user(),
        ]);
    }

    // Modifier mon profil client
    public function update(Request $request)
    {
        $client = $request->user()->client;

        if (! $client) {
            return response()->json(['message' => 'Profil client introuvable'], 404);
        }

        $validator = Validator::make($request->all(), [
            'name' => 'sometimes|required|string|max:255',
            'email' => ['sometimes', 'required', 'email', 'max:255', Rule::unique('users')->ignore($request->user()->id)],
            'telephone' => ['sometimes', 'required', 'string', 'max:20', Rule::unique('users')->ignore($request->user()->id)],
            'nom' => 'sometimes|string|max:255',
            'prenom' => 'sometimes|nullable|string|max:255',
            'adresse_texte' => 'sometimes|nullable|string|max:255',
            'latitude' => 'sometimes|nullable|numeric',
            'longitude' => 'sometimes|nullable|numeric',
            'current_password' => 'required_with:password|string',
            'password' => 'sometimes|string|min:8|max:128|confirmed',
        ], [
            'name.required' => 'Le nom est obligatoire.',
            'email.required' => 'L’adresse email est obligatoire.',
            'email.email' => 'L’adresse email n’est pas valide.',
            'email.unique' => 'Cette adresse email est déjà utilisée.',
            'telephone.required' => 'Le numéro de téléphone est obligatoire.',
            'telephone.unique' => 'Ce numéro de téléphone est déjà utilisé.',
            'adresse_texte.required' => 'L’adresse de livraison est obligatoire.',
            'latitude.required' => 'La position actuelle doit être renseignée.',
            'longitude.required' => 'La position actuelle doit être renseignée.',
            'password.min' => 'Le nouveau mot de passe doit contenir au moins 8 caractères.',
            'password.confirmed' => 'La confirmation du mot de passe ne correspond pas.',
            'current_password.required_with' => 'Le mot de passe actuel est obligatoire.',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $validated = $validator->validated();
        if (isset($validated['password']) && ! Hash::check($validated['current_password'], $request->user()->password)) {
            return response()->json(['message' => 'Le mot de passe actuel est incorrect.'], 422);
        }

        DB::transaction(function () use ($client, $request, $validated) {
            $userData = collect($validated)->only(['name', 'email', 'telephone'])->all();
            if (isset($validated['password'])) {
                $userData['password'] = Hash::make($validated['password']);
            }
            $request->user()->update($userData);
            $client->update(collect($validated)->only([
                'nom', 'prenom', 'adresse_texte', 'latitude', 'longitude',
            ])->all());
        });

        return response()->json([
            'message' => 'Profil mis à jour',
            'client' => $client,
            'user' => $request->user()->fresh(),
        ]);
    }

    /**
     * Supprime l'acces du client et anonymise ses donnees de profil, sans
     * detruire commandes et paiements necessaires a la tracabilite.
     */
    public function destroy(Request $request)
    {
        $client = $request->user()->client;
        $user = $request->user();

        if (! $client) {
            return response()->json(['message' => 'Profil client introuvable'], 404);
        }

        $validated = $request->validate([
            'confirmation' => ['required', 'in:SUPPRIMER'],
            'current_password' => ['required', 'string'],
        ], [
            'confirmation.in' => 'Saisissez exactement SUPPRIMER pour confirmer.',
            'current_password.required' => 'Votre mot de passe est requis pour cette action.',
        ]);

        if (! Hash::check($validated['current_password'], $user->password)) {
            return response()->json(['message' => 'Le mot de passe actuel est incorrect.'], 422);
        }

        $commandeActive = $client->commandes()
            ->whereNotIn('statut', [Commande::STATUT_LIVREE, Commande::STATUT_ANNULEE])
            ->exists();
        $paiementActif = Paiement::query()
            ->whereIn('statut', Paiement::STATUTS_ACTIFS)
            ->whereIn('commande_id', $client->commandes()->select('id'))
            ->exists();

        if ($commandeActive || $paiementActif) {
            return response()->json([
                'message' => 'Votre compte ne peut pas être supprimé tant qu’une commande ou un paiement est en cours.',
                'code' => 'SUPPRESSION_COMPTE_BLOQUEE',
            ], 422);
        }

        DB::transaction(function () use ($client, $user): void {
            $suffixe = $user->id.'-'.Str::lower(Str::random(20));

            $user->pushTokens()->delete();
            $user->tokens()->delete();
            EmailAuthCode::query()->where('user_id', $user->id)->delete();

            $client->update([
                'nom' => null,
                'prenom' => null,
                'adresse_texte' => null,
                'latitude' => null,
                'longitude' => null,
            ]);

            $user->forceFill([
                'name' => 'Compte supprimé',
                'email' => 'supprime-'.$suffixe.'@deleted.hotkokichaud.digital',
                'telephone' => 'del-'.$user->id.'-'.Str::lower(Str::random(10)),
                'password' => Hash::make(Str::random(64)),
                'email_verified_at' => null,
            ])->save();
            $user->delete();
        });

        return response()->json([
            'message' => 'Votre compte a été supprimé. Les historiques de commande sont conservés de façon anonymisée pour les obligations de traçabilité.',
        ]);
    }
}
