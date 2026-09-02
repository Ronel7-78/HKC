<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Commande;
use App\Services\NotificationService;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class VendeurCommandeController extends Controller
{
    public function index(Request $request)
    {
        $vendeur = $request->user()->vendeur;

        if (! $vendeur) {
            return response()->json(['message' => 'Ce compte n\'a pas de profil vendeur associé.'], 403);
        }

        return response()->json(
            $vendeur->commandes()
                ->with('client.user', 'items.complements', 'items.produit', 'paiements')
                ->latest()
                ->get()
        );
    }

    public function show(Request $request, Commande $commande)
    {
        $this->authorize('vendeur', $commande);

        return response()->json(
            $commande->load('client.user', 'items.complements', 'items.produit', 'paiements')
        );
    }

    public function updateStatut(Request $request, Commande $commande)
    {
        $this->authorize('vendeur', $commande);

        $validated = $request->validate([
            'statut' => ['required', 'string', Rule::in(Commande::STATUTS)],
        ]);

        if (! $commande->peutPasserAuStatut($validated['statut'])) {
            return response()->json([
                'message' => "Transition de {$commande->statut} vers {$validated['statut']} impossible.",
            ], 422);
        }

        $commande->update(['statut' => $validated['statut']]);
        $commande->load('client.user');
        $libelles = [
            Commande::STATUT_RECUE => 'reçue',
            Commande::STATUT_PREPARATION => 'en préparation',
            Commande::STATUT_EN_LIVRAISON => 'en livraison',
            Commande::STATUT_LIVREE => 'livrée',
            Commande::STATUT_ANNULEE => 'annulée',
        ];
        NotificationService::envoyer(
            $commande->client->user,
            'statut_commande',
            'Commande mise à jour',
            "Votre commande #{$commande->id} est désormais ".($libelles[$commande->statut] ?? $commande->statut).'.',
            ['commande_id' => $commande->id, 'statut' => $commande->statut]
        );

        return response()->json([
            'message' => 'Statut de la commande mis à jour.',
            'commande' => $commande->fresh()->load('client.user', 'items.complements', 'items.produit', 'paiements'),
        ]);
    }
}
