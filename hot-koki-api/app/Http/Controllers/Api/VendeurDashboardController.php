<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Avis;
use App\Models\Commande;
use App\Services\RevenueReportService;
use Illuminate\Http\Request;

class VendeurDashboardController extends Controller
{
    public function dashboard(Request $request, RevenueReportService $revenueReport)
    {
        $vendeur = $request->user()->vendeur;
        $commandes = $vendeur->commandes();

        $revenus = $revenueReport->totals($vendeur->id);

        return response()->json([
            'vendeur' => $vendeur,
            'statistiques' => [
                'commandes_du_jour' => (clone $commandes)->whereDate('created_at', today())->count(),
                'a_preparer' => (clone $commandes)->whereIn('statut', [Commande::STATUT_RECUE, Commande::STATUT_PREPARATION])->count(),
                'en_livraison' => (clone $commandes)->where('statut', Commande::STATUT_EN_LIVRAISON)->count(),
                'livrees' => (clone $commandes)->where('statut', Commande::STATUT_LIVREE)->count(),
                'annulees' => (clone $commandes)->where('statut', Commande::STATUT_ANNULEE)->count(),
                'chiffre_affaires' => $revenus['total'],
                'chiffre_affaires_jour' => $revenus['jour'],
                'chiffre_affaires_semaine' => $revenus['semaine'],
                'chiffre_affaires_mois' => $revenus['mois'],
                'paiements_reussis' => $revenus['paiements_reussis'],
                'note_moyenne' => (float) $vendeur->note_moyenne,
                'nombre_avis' => Avis::where('vendeur_id', $vendeur->id)->count(),
            ],
            'revenus' => $revenus,
            'commandes_recentes' => $vendeur->commandes()
                ->with('client.user', 'items.produit', 'items.complements')
                ->latest()
                ->limit(5)
                ->get(),
            'avis_recents' => Avis::where('vendeur_id', $vendeur->id)
                ->with('commande.client.user')
                ->latest()
                ->limit(5)
                ->get(),
        ]);
    }

    public function avis(Request $request)
    {
        return response()->json(
            Avis::where('vendeur_id', $request->user()->vendeur->id)
                ->with('commande.client.user')
                ->latest()
                ->paginate(30)
        );
    }
}
