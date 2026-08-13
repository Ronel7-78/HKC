<?php

// app/Http/Controllers/Api/ClientController.php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;
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
            'email' => ['sometimes', 'required', 'email', Rule::unique('users')->ignore($request->user()->id)],
            'telephone' => ['sometimes', 'required', 'string', Rule::unique('users')->ignore($request->user()->id)],
            'nom' => 'sometimes|string|max:255',
            'prenom' => 'sometimes|nullable|string|max:255',
            'adresse_texte' => 'sometimes|nullable|string|max:255',
            'latitude' => 'sometimes|nullable|numeric',
            'longitude' => 'sometimes|nullable|numeric',
            'current_password' => 'required_with:password|string',
            'password' => 'sometimes|string|min:8|confirmed',
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
}
