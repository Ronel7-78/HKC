<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Commande;
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
        if (! $this->estCommandeDuVendeur($request, $commande)) {
            return response()->json(['message' => 'Cette commande n\'est pas affectée à ce vendeur.'], 403);
        }

        return response()->json(
            $commande->load('client.user', 'items.complements', 'items.produit', 'paiements')
        );
    }

    public function updateStatut(Request $request, Commande $commande)
    {
        if (! $this->estCommandeDuVendeur($request, $commande)) {
            return response()->json(['message' => 'Cette commande n\'est pas affectée à ce vendeur.'], 403);
        }

        $validated = $request->validate([
            'statut' => ['required', 'string', Rule::in(Commande::STATUTS)],
        ]);

        if (! $commande->peutPasserAuStatut($validated['statut'])) {
            return response()->json([
                'message' => "Transition de {$commande->statut} vers {$validated['statut']} impossible.",
            ], 422);
        }

        $commande->update(['statut' => $validated['statut']]);

        return response()->json([
            'message' => 'Statut de la commande mis à jour.',
            'commande' => $commande->fresh()->load('client.user', 'items.complements', 'items.produit', 'paiements'),
        ]);
    }

    private function estCommandeDuVendeur(Request $request, Commande $commande): bool
    {
        $vendeur = $request->user()->vendeur;

        return $vendeur && $commande->vendeur_id === $vendeur->id;
    }
}
