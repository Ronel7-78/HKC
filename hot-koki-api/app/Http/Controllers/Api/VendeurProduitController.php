<?php
// app/Http/Controllers/Api/VendeurProduitController.php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Produit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class VendeurProduitController extends Controller
{
    // Voir le catalogue complet + mon statut sur chaque produit
    public function index(Request $request)
    {
        $vendeur = $request->user()->vendeur;

        if (!$vendeur) {
            return response()->json(['message' => 'Profil vendeur introuvable'], 404);
        }

        $produits = Produit::with('complements')->get()->map(function ($produit) use ($vendeur) {
            $pivot = $vendeur->produits()->where('produit_id', $produit->id)->first();
            $produit->mon_statut = $pivot ? $pivot->pivot->statut : 'rupture';
            return $produit;
        });

        return response()->json($produits);
    }

    // Basculer disponible/rupture sur un produit du catalogue
    public function updateStatut(Request $request, $produitId)
    {
        $vendeur = $request->user()->vendeur;

        if (!$vendeur) {
            return response()->json(['message' => 'Profil vendeur introuvable'], 404);
        }

        $validator = Validator::make($request->all(), [
            'statut' => 'required|in:disponible,rupture',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        Produit::findOrFail($produitId); // vérifie que le produit existe bien au catalogue

        $vendeur->produits()->syncWithoutDetaching([
            $produitId => ['statut' => $request->statut],
        ]);

        return response()->json(['message' => 'Statut mis à jour']);
    }
}