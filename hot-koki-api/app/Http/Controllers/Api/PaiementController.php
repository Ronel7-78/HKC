<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Commande;
use App\Models\Paiement;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class PaiementController extends Controller
{
    public function store(Request $request, Commande $commande)
    {
        $client = $request->user()->client;

        if (! $client || $commande->client_id !== $client->id) {
            return response()->json(['message' => 'Cette commande n’appartient pas à ce client.'], 403);
        }

        $validated = $request->validate([
            'fournisseur' => ['required', Rule::in([Paiement::FOURNISSEUR_MTN_MOMO])],
            'telephone' => ['required', 'string', 'regex:/^(?:\+?237)?6\d{8}$/'],
        ], [
            'telephone.regex' => 'Le numéro doit être un numéro camerounais valide.',
        ]);

        $paiement = DB::transaction(function () use ($commande, $validated) {
            $commandeVerrouillee = Commande::whereKey($commande->id)->lockForUpdate()->firstOrFail();

            if ($commandeVerrouillee->statut !== Commande::STATUT_EN_ATTENTE_PAIEMENT) {
                return null;
            }

            $tentativeActive = $commandeVerrouillee->paiements()
                ->whereIn('statut', Paiement::STATUTS_ACTIFS)
                ->latest()
                ->first();

            if ($tentativeActive) {
                return $tentativeActive;
            }

            return $commandeVerrouillee->paiements()->create([
                'fournisseur' => $validated['fournisseur'],
                'telephone' => $this->normaliserTelephone($validated['telephone']),
                'montant' => $commandeVerrouillee->total,
                'devise' => 'XAF',
                'statut' => Paiement::STATUT_INITIE,
            ]);
        });

        if (! $paiement) {
            return response()->json([
                'message' => 'Cette commande n’est plus en attente de paiement.',
                'code' => 'COMMANDE_NON_PAYABLE',
            ], 422);
        }

        return response()->json([
            'message' => 'Tentative de paiement créée. L’envoi à MTN MoMo sera activé après configuration du sandbox.',
            'paiement' => $paiement,
        ], $paiement->wasRecentlyCreated ? 201 : 200);
    }

    public function show(Request $request, Paiement $paiement)
    {
        if ($paiement->commande->client_id !== $request->user()->client?->id) {
            return response()->json(['message' => 'Ce paiement n’appartient pas à ce client.'], 403);
        }

        return response()->json($paiement->load('commande'));
    }

    private function normaliserTelephone(string $telephone): string
    {
        $telephone = ltrim($telephone, '+');

        return str_starts_with($telephone, '237') ? $telephone : '237'.$telephone;
    }
}
