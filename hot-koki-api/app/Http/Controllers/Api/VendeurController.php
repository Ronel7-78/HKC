<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rule;

class VendeurController extends Controller
{
    public function show(Request $request)
    {
        $vendeur = $request->user()->vendeur;
        if (! $vendeur) {
            return response()->json(['message' => 'Profil vendeur introuvable.'], 404);
        }

        return response()->json(['vendeur' => $vendeur, 'user' => $request->user()]);
    }

    public function update(Request $request)
    {
        $vendeur = $request->user()->vendeur;
        if (! $vendeur) {
            return response()->json(['message' => 'Profil vendeur introuvable.'], 404);
        }

        $validator = Validator::make($request->all(), [
            'name' => 'sometimes|required|string|max:255',
            'email' => ['sometimes', 'required', 'email', Rule::unique('users')->ignore($request->user()->id)],
            'telephone' => ['sometimes', 'required', 'string', 'max:20', Rule::unique('users')->ignore($request->user()->id)],
            'nom_boutique' => 'sometimes|required|string|max:255',
            'description' => 'sometimes|nullable|string|max:2000',
            'adresse_texte' => 'sometimes|required|string|max:255',
            'latitude' => 'sometimes|required|numeric|between:-90,90',
            'longitude' => 'sometimes|required|numeric|between:-180,180',
            'current_password' => 'required_with:password|string',
            'password' => 'sometimes|string|min:8|max:128|confirmed',
        ], [
            'required' => 'Le champ :attribute est obligatoire.',
            'email.email' => 'L’adresse email n’est pas valide.',
            'email.unique' => 'Cette adresse email est déjà utilisée.',
            'telephone.unique' => 'Ce numéro de téléphone est déjà utilisé.',
            'password.min' => 'Le mot de passe doit contenir au moins 8 caractères.',
            'password.confirmed' => 'La confirmation du mot de passe ne correspond pas.',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $validated = $validator->validated();
        if (isset($validated['password']) && ! Hash::check($validated['current_password'], $request->user()->password)) {
            return response()->json(['message' => 'Le mot de passe actuel est incorrect.'], 422);
        }

        DB::transaction(function () use ($vendeur, $request, $validated) {
            $userData = collect($validated)->only(['name', 'email', 'telephone'])->all();
            if (isset($validated['password'])) {
                $userData['password'] = Hash::make($validated['password']);
            }
            $request->user()->update($userData);
            $vendeur->update(collect($validated)->only([
                'nom_boutique', 'description', 'adresse_texte', 'latitude', 'longitude',
            ])->all());
        });

        return response()->json([
            'message' => 'Profil vendeur mis à jour.',
            'vendeur' => $vendeur->fresh(),
            'user' => $request->user()->fresh(),
        ]);
    }

    public function updateDisponibilite(Request $request)
    {
        $vendeur = $request->user()->vendeur;
        if (! $vendeur) {
            return response()->json(['message' => 'Profil vendeur introuvable.'], 404);
        }
        if ($vendeur->statut_compte === 'suspendu') {
            return response()->json(['message' => 'Compte suspendu : la disponibilité ne peut pas être modifiée.'], 403);
        }

        $validated = $request->validate([
            'statut_dispo' => 'required|in:disponible,pause,indisponible',
        ], ['statut_dispo.required' => 'Choisissez votre disponibilité.']);

        $vendeur->update(['statut_dispo' => $validated['statut_dispo']]);

        return response()->json([
            'message' => 'Disponibilité mise à jour.',
            'statut_dispo' => $vendeur->statut_dispo,
        ]);
    }
}
