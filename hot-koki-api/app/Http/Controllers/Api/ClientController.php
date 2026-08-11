<?php
// app/Http/Controllers/Api/ClientController.php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class ClientController extends Controller
{
    // Voir mon profil client
    public function show(Request $request)
    {
        $client = $request->user()->client;

        if (!$client) {
            return response()->json(['message' => 'Profil client introuvable'], 404);
        }

        return response()->json($client);
    }

    // Modifier mon profil client
    public function update(Request $request)
    {
        $client = $request->user()->client;

        if (!$client) {
            return response()->json(['message' => 'Profil client introuvable'], 404);
        }

        $validator = Validator::make($request->all(), [
            'nom' => 'sometimes|string|max:255',
            'prenom' => 'sometimes|nullable|string|max:255',
            'adresse_texte' => 'sometimes|nullable|string|max:255',
            'latitude' => 'sometimes|nullable|numeric',
            'longitude' => 'sometimes|nullable|numeric',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $client->update($validator->validated());

        return response()->json([
            'message' => 'Profil mis à jour',
            'client' => $client,
        ]);
    }
}