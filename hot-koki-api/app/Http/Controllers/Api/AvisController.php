<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Avis;
use App\Models\Commande;
use App\Models\Vendeur;
use App\Services\NotificationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class AvisController extends Controller
{
    public function index(Request $request)
    {
        return response()->json(
            Avis::where('client_id', $request->user()->client->id)
                ->with('commande.vendeur')
                ->latest()
                ->get()
        );
    }

    public function store(Request $request, Commande $commande)
    {
        $client = $request->user()->client;
        if (! $client || $commande->client_id !== $client->id) {
            return response()->json(['message' => 'Cette commande n’appartient pas à ce client.'], 403);
        }
        if ($commande->statut !== Commande::STATUT_LIVREE) {
            return response()->json(['message' => 'Vous pourrez donner votre avis après la livraison.'], 422);
        }
        $validated = $request->validate([
            'note' => 'required|integer|between:1,5',
            'commentaire' => 'nullable|string|max:1000',
        ]);

        $avis = DB::transaction(function () use ($commande, $client, $validated) {
            $avis = Avis::updateOrCreate(
                ['commande_id' => $commande->id],
                [
                    'client_id' => $client->id,
                    'vendeur_id' => $commande->vendeur_id,
                    ...$validated,
                ]
            );
            Vendeur::whereKey($commande->vendeur_id)->update([
                'note_moyenne' => round((float) Avis::where('vendeur_id', $commande->vendeur_id)->avg('note'), 2),
            ]);

            return $avis;
        });

        $commande->load('vendeur.user');
        NotificationService::envoyer(
            $commande->vendeur->user,
            'nouvel_avis',
            'Nouvel avis client',
            "Vous avez reçu une note de {$avis->note}/5 pour la commande #{$commande->id}.",
            ['commande_id' => $commande->id, 'avis_id' => $avis->id]
        );
        NotificationService::admins(
            'nouvel_avis',
            'Nouvel avis publié',
            "Un avis de {$avis->note}/5 a été publié pour la commande #{$commande->id}.",
            ['commande_id' => $commande->id, 'avis_id' => $avis->id]
        );

        return response()->json(['message' => 'Merci pour votre avis.', 'avis' => $avis]);
    }
}
