<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Produit;

class CatalogueController extends Controller
{
    public function index()
    {
        $produits = Produit::query()
            ->with('complements:id,nom')
            ->withCount([
                'vendeurs as vendeurs_disponibles_count' => fn ($query) => $query
                    ->where('vendeurs.statut_compte', 'actif')
                    ->where('vendeurs.statut_dispo', 'disponible')
                    ->where('vendeur_produits.statut', 'disponible'),
            ])
            ->orderBy('nom')
            ->get()
            ->map(fn (Produit $produit) => [
                'id' => $produit->id,
                'nom' => $produit->nom,
                'description' => $produit->description,
                'prix' => $produit->prix,
                'photo' => $produit->photo,
                'complements' => $produit->complements,
                'disponible' => $produit->vendeurs_disponibles_count > 0,
                'vendeurs_disponibles' => $produit->vendeurs_disponibles_count,
            ]);

        return response()->json(['produits' => $produits]);
    }
}
