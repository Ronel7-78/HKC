<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Commande;
use App\Models\Paiement;
use App\Services\Payments\MtnMomoService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use RuntimeException;

class PaiementController extends Controller
{
    public function store(Request $request, Commande $commande, MtnMomoService $mtnMomo)
    {
        $client = $request->user()->client;

        if (! $client || $commande->client_id !== $client->id) {
            return response()->json(['message' => 'Cette commande n’appartient pas à ce client.'], 403);
        }

        $telephoneRegex = config('services.mtn_momo.target_environment') === 'sandbox'
            ? '/^(?:(?:\+?237)?6\d{8}|46\d{9})$/'
            : '/^(?:\+?237)?6\d{8}$/';

        $validated = $request->validate([
            'fournisseur' => ['required', Rule::in([Paiement::FOURNISSEUR_MTN_MOMO])],
            'telephone' => ['required', 'string', 'regex:'.$telephoneRegex],
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

        if ($paiement->wasRecentlyCreated || $paiement->statut === Paiement::STATUT_INITIE) {
            try {
                $mtnMomo->initier($paiement);
                $paiement->refresh();
            } catch (RuntimeException) {
                return response()->json([
                    'message' => 'Le paiement a été enregistré, mais MTN MoMo n’a pas pu être contacté.',
                    'code' => 'MTN_MOMO_INDISPONIBLE',
                    'paiement' => $paiement->fresh(),
                ], 502);
            }
        }

        return response()->json([
            'message' => $paiement->wasRecentlyCreated
                ? 'Demande de paiement envoyée à MTN MoMo.'
                : 'Une demande de paiement est déjà en cours.',
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

    public function synchroniser(Request $request, Paiement $paiement, MtnMomoService $mtnMomo)
    {
        if ($paiement->commande->client_id !== $request->user()->client?->id) {
            return response()->json(['message' => 'Ce paiement n’appartient pas à ce client.'], 403);
        }

        if ($paiement->prochaine_verification_le?->isFuture()) {
            return response()->json([
                'message' => 'La prochaine vérification est temporairement différée.',
                'paiement' => $paiement,
            ], 202);
        }

        if ($paiement->tentatives_statut >= config('services.mtn_momo.poll_max_attempts')) {
            if ($request->boolean('relancer')) {
                $paiement->update([
                    'tentatives_statut' => 0,
                    'prochaine_verification_le' => now(),
                ]);
            } else {
                return response()->json([
                    'message' => 'La durée maximale de vérification automatique est atteinte.',
                    'code' => 'POLLING_TERMINE',
                    'paiement' => $paiement,
                ], 202);
            }
        }

        try {
            $paiement = $mtnMomo->synchroniser($paiement);
        } catch (RuntimeException $exception) {
            return response()->json([
                'message' => 'Le statut MTN MoMo est temporairement indisponible. '.$exception->getMessage(),
                'code' => 'STATUT_MTN_INDISPONIBLE',
                'detail' => $exception->getMessage(),
                'paiement' => $paiement->fresh(),
            ], 503);
        }

        return response()->json($paiement->load('commande'));
    }

    private function normaliserTelephone(string $telephone): string
    {
        $telephone = ltrim($telephone, '+');

        if (config('services.mtn_momo.target_environment') === 'sandbox' && str_starts_with($telephone, '46')) {
            return $telephone;
        }

        return str_starts_with($telephone, '237') ? $telephone : '237'.$telephone;
    }
}
