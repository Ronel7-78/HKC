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

        $effectiveLatitude = "CASE WHEN type_vendeur = 'ambulant' AND live_latitude IS NOT NULL THEN live_latitude ELSE latitude END";
        $effectiveLongitude = "CASE WHEN type_vendeur = 'ambulant' AND live_longitude IS NOT NULL THEN live_longitude ELSE longitude END";
        $distance = "(6371 * acos(cos(radians(?)) * cos(radians({$effectiveLatitude})) * cos(radians({$effectiveLongitude}) - radians(?)) + sin(radians(?)) * sin(radians({$effectiveLatitude}))))";
        $recherche = trim((string) $request->query('q'));
        $type = $request->query('type');

        $vendeurs = Vendeur::query()
            ->where('statut_compte', 'actif')
            ->where('statut_dispo', 'disponible')
            ->whereRaw("{$effectiveLatitude} IS NOT NULL")
            ->whereRaw("{$effectiveLongitude} IS NOT NULL")
            ->when(in_array($type, [Vendeur::TYPE_AMBULANT, Vendeur::TYPE_POINT_FIXE], true),
                fn ($query) => $query->where('type_vendeur', $type))
            ->when($request->boolean('express'), fn ($query) => $query
                ->where('type_vendeur', Vendeur::TYPE_POINT_FIXE)
                ->where('accepte_express', true))
            ->when($recherche, fn ($query) => $query->where(function ($query) use ($recherche) {
                $query->where('nom_boutique', 'like', "%{$recherche}%")
                    ->orWhereHas('produits', fn ($query) => $query->where('nom', 'like', "%{$recherche}%"));
            }))
            ->with([
                'user:id,telephone',
                'produits' => fn ($query) => $query
                    ->where('vendeur_produits.statut', 'disponible')
                    ->with('complements'),
            ])
            ->selectRaw("vendeurs.*, {$effectiveLatitude} AS effective_latitude, {$effectiveLongitude} AS effective_longitude, {$distance} AS distance_km", [
                $client->latitude,
                $client->longitude,
                $client->latitude,
            ])
            ->orderBy('distance_km')
            ->get()
            ->each(fn (Vendeur $vendeur) => $this->decorateLocation($vendeur));

        return response()->json(['vendeurs' => $vendeurs]);
    }

    public function show(Request $request, Vendeur $vendeur)
    {
        if ($vendeur->statut_compte !== 'actif') {
            abort(404);
        }

        $client = $request->user()->client;
        $vendeur->load([
            'user:id,telephone',
            'produits' => fn ($query) => $query
                ->where('vendeur_produits.statut', 'disponible')
                ->with('complements'),
        ]);

        $this->decorateLocation($vendeur);
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

    private function decorateLocation(Vendeur $vendeur): void
    {
        $isMobile = $vendeur->type_vendeur === Vendeur::TYPE_AMBULANT;
        $hasLive = $isMobile && $vendeur->live_latitude !== null && $vendeur->live_longitude !== null;
        $updatedAt = $vendeur->location_updated_at;

        $latitude = $vendeur->getAttribute('effective_latitude') ?? ($hasLive ? $vendeur->live_latitude : $vendeur->latitude);
        $longitude = $vendeur->getAttribute('effective_longitude') ?? ($hasLive ? $vendeur->live_longitude : $vendeur->longitude);
        $status = ! $isMobile
            ? 'fixe'
            : ($hasLive && $updatedAt?->isAfter(now()->subMinutes(5)) ? 'live' : ($hasLive ? 'derniere_position' : 'enregistree'));

        $vendeur->setAttribute('latitude', $latitude);
        $vendeur->setAttribute('longitude', $longitude);
        $vendeur->setAttribute('position_status', $status);
        $vendeur->setAttribute('position_updated_at', $updatedAt?->toIso8601String());
        $vendeur->makeHidden(['live_latitude', 'live_longitude', 'location_updated_at', 'effective_latitude', 'effective_longitude']);
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
