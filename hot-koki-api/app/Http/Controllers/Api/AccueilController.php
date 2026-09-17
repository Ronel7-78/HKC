<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Annonce;
use App\Models\Avis;
use App\Models\Vendeur;
use Illuminate\Http\Request;

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
                ->where('accepte_express', true)
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

    public function avis(Request $request)
    {
        return response()->json(
            Avis::query()
                ->whereNotNull('commentaire')
                ->where('commentaire', '<>', '')
                ->with('client.user:id,name', 'vendeur:id,nom_boutique')
                ->latest()
                ->paginate(min(max((int) $request->query('par_page', 20), 1), 50))
        );
    }
}
