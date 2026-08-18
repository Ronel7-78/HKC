<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Avis;
use App\Models\Commande;
use App\Models\Paiement;
use Illuminate\Http\Request;

class VendeurDashboardController extends Controller
{
    public function dashboard(Request $request)
    {
        $vendeur = $request->user()->vendeur;
        $commandes = $vendeur->commandes();

        return response()->json([
            'vendeur' => $vendeur,
            'statistiques' => [
                'commandes_du_jour' => (clone $commandes)->whereDate('created_at', today())->count(),
                'a_preparer' => (clone $commandes)->whereIn('statut', [Commande::STATUT_RECUE, Commande::STATUT_PREPARATION])->count(),
                'en_livraison' => (clone $commandes)->where('statut', Commande::STATUT_EN_LIVRAISON)->count(),
                'livrees' => (clone $commandes)->where('statut', Commande::STATUT_LIVREE)->count(),
                'annulees' => (clone $commandes)->where('statut', Commande::STATUT_ANNULEE)->count(),
                'chiffre_affaires' => Paiement::where('statut', Paiement::STATUT_REUSSI)
                    ->whereHas('commande', fn ($query) => $query->where('vendeur_id', $vendeur->id))
                    ->sum('montant'),
                'note_moyenne' => (float) $vendeur->note_moyenne,
                'nombre_avis' => Avis::where('vendeur_id', $vendeur->id)->count(),
            ],
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
