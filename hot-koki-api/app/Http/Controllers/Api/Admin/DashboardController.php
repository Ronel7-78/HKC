<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Commande;
use App\Models\Produit;
use App\Models\User;
use App\Models\Vendeur;
use App\Services\RevenueReportService;

class DashboardController extends Controller
{
    public function __invoke(RevenueReportService $revenueReport)
    {
        $revenus = $revenueReport->totals();

        return response()->json([
            'statistiques' => [
                'vendeurs_actifs' => Vendeur::where('statut_compte', 'actif')->count(),
                'commandes_du_jour' => Commande::whereDate('created_at', today())->count(),
                'chiffre_affaires_du_jour' => $revenus['jour'],
                'utilisateurs' => User::count(),
                'produits' => Produit::count(),
            ],
            'revenus' => $revenus,
            'revenus_par_vendeur' => $revenueReport->byVendor(),
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
