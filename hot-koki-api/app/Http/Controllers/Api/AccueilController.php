<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Annonce;
use App\Models\Avis;
use App\Models\Vendeur;

class AccueilController extends Controller
{
    public function __invoke()
    {
        return response()->json([
            'annonces' => Annonce::query()
                ->where('active', true)
                ->with('produit:id,nom,photo,prix')
                ->orderBy('ordre')
                ->latest('id')
                ->get(),
            'avis' => Avis::query()
                ->whereNotNull('commentaire')
                ->where('commentaire', '<>', '')
                ->with('client.user:id,name', 'vendeur:id,nom_boutique')
                ->latest()
                ->limit(10)
                ->get(),
            'points_fixes' => Vendeur::query()
                ->where('type_vendeur', Vendeur::TYPE_POINT_FIXE)
                ->where('statut_compte', 'actif')
                ->where('statut_dispo', 'disponible')
                ->with('user:id,telephone')
                ->withCount(['produits as produits_disponibles_count' => fn ($query) => $query
                    ->where('vendeur_produits.statut', 'disponible')])
                ->latest()
                ->limit(6)
                ->get(),
        ]);
    }
}
