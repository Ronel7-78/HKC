<?php
// app/Http/Controllers/Api/VendeurController.php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class VendeurController extends Controller
{
    public function show(Request $request)
    {
        $vendeur = $request->user()->vendeur;

        if (!$vendeur) {
            return response()->json(['message' => 'Profil vendeur introuvable'], 404);
        }

        return response()->json($vendeur);
    }

    public function update(Request $request)
    {
        $vendeur = $request->user()->vendeur;

        if (!$vendeur) {
            return response()->json(['message' => 'Profil vendeur introuvable'], 404);
        }

        $validator = Validator::make($request->all(), [
            'nom_boutique' => 'sometimes|string|max:255',
            'description' => 'sometimes|nullable|string',
            'adresse_texte' => 'sometimes|nullable|string|max:255',
            'latitude' => 'sometimes|nullable|numeric',
            'longitude' => 'sometimes|nullable|numeric',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $vendeur->update($validator->validated());

        return response()->json(['message' => 'Profil mis à jour', 'vendeur' => $vendeur]);
    }

    // Endpoint dédié pour le switch de disponibilité (celui du mockup espace vendeur)
    public function updateDisponibilite(Request $request)
    {
        $vendeur = $request->user()->vendeur;

        if (!$vendeur) {
            return response()->json(['message' => 'Profil vendeur introuvable'], 404);
        }

        if ($vendeur->statut_compte === 'suspendu') {
            return response()->json(['message' => 'Compte suspendu — impossible de changer la disponibilité'], 403);
        }

        $validator = Validator::make($request->all(), [
            'statut_dispo' => 'required|in:disponible,pause,indisponible',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $vendeur->update(['statut_dispo' => $request->statut_dispo]);

        return response()->json(['message' => 'Disponibilité mise à jour', 'statut_dispo' => $vendeur->statut_dispo]);
    }
}