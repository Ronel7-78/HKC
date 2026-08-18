<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Annonce;
use App\Models\Avis;

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
        ]);
    }
}
