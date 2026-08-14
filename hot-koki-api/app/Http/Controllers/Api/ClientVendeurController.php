<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Vendeur;
use Illuminate\Http\Request;

class ClientVendeurController extends Controller
{
    public function index(Request $request)
    {
        $client = $request->user()->client;

        if (! $client?->latitude || ! $client?->longitude) {
            return response()->json([
                'message' => 'Ajoutez une position à votre profil pour rechercher les vendeurs proches.',
                'code' => 'LOCALISATION_CLIENT_REQUISE',
            ], 422);
        }

        $distance = '(6371 * acos(cos(radians(?)) * cos(radians(latitude)) * cos(radians(longitude) - radians(?)) + sin(radians(?)) * sin(radians(latitude))))';
        $recherche = trim((string) $request->query('q'));

        $vendeurs = Vendeur::query()
            ->where('statut_compte', 'actif')
            ->where('statut_dispo', 'disponible')
            ->whereNotNull('latitude')
            ->whereNotNull('longitude')
            ->when($recherche, fn ($query) => $query->where(function ($query) use ($recherche) {
                $query->where('nom_boutique', 'like', "%{$recherche}%")
                    ->orWhere('adresse_texte', 'like', "%{$recherche}%")
                    ->orWhereHas('produits', fn ($query) => $query->where('nom', 'like', "%{$recherche}%"));
            }))
            ->with(['produits' => fn ($query) => $query
                ->where('vendeur_produits.statut', 'disponible')
                ->with('complements')])
            ->selectRaw("vendeurs.*, {$distance} AS distance_km", [
                $client->latitude,
                $client->longitude,
                $client->latitude,
            ])
            ->orderBy('distance_km')
            ->get();

        return response()->json(['vendeurs' => $vendeurs]);
    }

    public function show(Request $request, Vendeur $vendeur)
    {
        if ($vendeur->statut_compte !== 'actif') {
            abort(404);
        }

        $client = $request->user()->client;
        $vendeur->load(['produits' => fn ($query) => $query
            ->where('vendeur_produits.statut', 'disponible')
            ->with('complements')]);

        $distanceKm = null;
        if ($client?->latitude && $client?->longitude && $vendeur->latitude && $vendeur->longitude) {
            $distanceKm = $this->distanceKm(
                (float) $client->latitude,
                (float) $client->longitude,
                (float) $vendeur->latitude,
                (float) $vendeur->longitude,
            );
        }

        return response()->json([
            'vendeur' => array_merge($vendeur->toArray(), [
                'distance_km' => $distanceKm === null ? null : round($distanceKm, 2),
            ]),
        ]);
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
