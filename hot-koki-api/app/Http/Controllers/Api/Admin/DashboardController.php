<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Commande;
use App\Models\Paiement;
use App\Models\Produit;
use App\Models\User;
use App\Models\Vendeur;

class DashboardController extends Controller
{
    public function __invoke()
    {
        return response()->json([
            'statistiques' => [
                'vendeurs_actifs' => Vendeur::where('statut_compte', 'actif')->count(),
                'commandes_du_jour' => Commande::whereDate('created_at', today())->count(),
                'chiffre_affaires_du_jour' => Paiement::where('statut', Paiement::STATUT_REUSSI)
                    ->whereDate('confirme_le', today())
                    ->sum('montant'),
                'utilisateurs' => User::count(),
                'produits' => Produit::count(),
            ],
            'vendeurs_recents' => Vendeur::with('user')->latest()->limit(5)->get(),
            'commandes_recentes' => Commande::with('client.user', 'vendeur')->latest()->limit(5)->get(),
        ]);
    }

    public function commandes()
    {
        return response()->json(
            Commande::with('client.user', 'vendeur', 'items.produit', 'paiements')
                ->latest()
                ->paginate(30)
        );
    }
}
