<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Produit;
use App\Models\Vendeur;
use Illuminate\Http\Request;

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

    public function client(Request $request)
    {
        $client = $request->user()->client;
        $produits = Produit::query()
            ->with('complements:id,nom')
            ->orderBy('nom')
            ->get()
            ->map(function (Produit $produit) use ($client) {
                $vendeurs = Vendeur::query()
                    ->where('statut_compte', 'actif')
                    ->where('statut_dispo', 'disponible')
                    ->whereHas('produits', fn ($query) => $query
                        ->whereKey($produit->id)
                        ->where('vendeur_produits.statut', 'disponible'))
                    ->get();

                $vendeur = $vendeurs->sortBy(function (Vendeur $vendeur) use ($client) {
                    if (! $client?->latitude || ! $client?->longitude || ! $vendeur->latitude || ! $vendeur->longitude) {
                        return PHP_FLOAT_MAX;
                    }

                    return $this->distanceKm(
                        (float) $client->latitude,
                        (float) $client->longitude,
                        (float) $vendeur->latitude,
                        (float) $vendeur->longitude,
                    );
                })->first();

                return [
                    'id' => $produit->id,
                    'nom' => $produit->nom,
                    'description' => $produit->description,
                    'prix' => $produit->prix,
                    'photo' => $produit->photo,
                    'complements' => $produit->complements,
                    'disponible' => $vendeur !== null,
                    'vendeur_choisi' => $vendeur ? [
                        'id' => $vendeur->id,
                        'nom_boutique' => $vendeur->nom_boutique,
                    ] : null,
                ];
            });

        return response()->json(['produits' => $produits]);
    }

    private function distanceKm(float $lat1, float $lng1, float $lat2, float $lng2): float
    {
        $latDelta = deg2rad($lat2 - $lat1);
        $lngDelta = deg2rad($lng2 - $lng1);
        $a = sin($latDelta / 2) ** 2
            + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($lngDelta / 2) ** 2;

        return 6371 * 2 * atan2(sqrt($a), sqrt(1 - $a));
    }
}
