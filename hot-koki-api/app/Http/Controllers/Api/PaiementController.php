<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Commande;
use App\Models\Paiement;
use App\Services\Payments\MtnMomoService;
use App\Services\Payments\OrangeMoneyService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use RuntimeException;

class PaiementController extends Controller
{
    public function moyens()
    {
        return response()->json([
            ['code' => Paiement::FOURNISSEUR_MTN_MOMO, 'nom' => 'MTN MoMo', 'disponible' => true],
            ['code' => Paiement::FOURNISSEUR_ORANGE_MONEY, 'nom' => 'Orange Money', 'disponible' => (bool) config('services.orange_money.enabled')],
        ]);
    }

    public function store(
        Request $request,
        Commande $commande,
        MtnMomoService $mtnMomo,
        OrangeMoneyService $orangeMoney,
    ) {
        $this->authorize('client', $commande);
        $client = $request->user()->client;

        $telephoneRegex = $request->input('fournisseur') === Paiement::FOURNISSEUR_MTN_MOMO
            && config('services.mtn_momo.target_environment') === 'sandbox'
            ? '/^(?:(?:\+?237)?6\d{8}|46\d{9})$/'
            : '/^(?:\+?237)?6\d{8}$/';

        $validated = $request->validate([
            'fournisseur' => ['required', Rule::in([
                Paiement::FOURNISSEUR_MTN_MOMO,
                Paiement::FOURNISSEUR_ORANGE_MONEY,
            ])],
            'telephone' => ['required', 'string', 'max:20', 'regex:'.$telephoneRegex],
        ], [
            'telephone.regex' => 'Le numéro doit être un numéro camerounais valide.',
        ]);

        if ($validated['fournisseur'] === Paiement::FOURNISSEUR_ORANGE_MONEY
            && ! config('services.orange_money.enabled')) {
            return response()->json([
                'message' => 'Orange Money sera disponible prochainement.',
                'code' => 'ORANGE_MONEY_INDISPONIBLE',
            ], 503);
        }

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
                'telephone' => $this->normaliserTelephone(
                    $validated['telephone'],
                    $validated['fournisseur'],
                ),
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
                match ($paiement->fournisseur) {
                    Paiement::FOURNISSEUR_MTN_MOMO => $mtnMomo->initier($paiement),
                    Paiement::FOURNISSEUR_ORANGE_MONEY => $orangeMoney->initier($paiement),
                };
                $paiement->refresh();
            } catch (RuntimeException) {
                return response()->json([
                    'message' => 'Le paiement a été enregistré, mais l’opérateur n’a pas pu être contacté.',
                    'code' => 'OPERATEUR_INDISPONIBLE',
                    'paiement' => $paiement->fresh(),
                ], 502);
            }
        }

        return response()->json([
            'message' => $paiement->wasRecentlyCreated
                ? 'Demande de paiement envoyée à l’opérateur.'
                : 'Une demande de paiement est déjà en cours.',
            'paiement' => $paiement,
        ], $paiement->wasRecentlyCreated ? 201 : 200);
    }

    public function show(Request $request, Paiement $paiement)
    {
        $this->authorize('client', $paiement);

        return response()->json($paiement->load('commande'));
    }

    public function synchroniser(
        Request $request,
        Paiement $paiement,
        MtnMomoService $mtnMomo,
        OrangeMoneyService $orangeMoney,
    ) {
        $this->authorize('client', $paiement);

        if ($paiement->prochaine_verification_le?->isFuture()) {
            return response()->json([
                'message' => 'La prochaine vérification est temporairement différée.',
                'paiement' => $paiement,
            ], 202);
        }

        $tentativesMax = $paiement->fournisseur === Paiement::FOURNISSEUR_ORANGE_MONEY
            ? config('services.orange_money.poll_max_attempts')
            : config('services.mtn_momo.poll_max_attempts');
        if ($paiement->tentatives_statut >= $tentativesMax) {
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
            $paiement = match ($paiement->fournisseur) {
                Paiement::FOURNISSEUR_MTN_MOMO => $mtnMomo->synchroniser($paiement),
                Paiement::FOURNISSEUR_ORANGE_MONEY => $orangeMoney->synchroniser($paiement),
                default => throw new RuntimeException('Fournisseur de paiement inconnu.'),
            };
        } catch (RuntimeException $exception) {
            $incident = Str::lower(Str::random(16));
            Log::warning('Échec de synchronisation auprès de l’opérateur de paiement', [
                'incident_id' => $incident,
                'paiement_id' => $paiement->id,
                'fournisseur' => $paiement->fournisseur,
                'user_id' => $request->user()->id,
                'exception' => $exception,
            ]);

            return response()->json([
                'message' => 'Le statut du paiement est temporairement indisponible.',
                'code' => 'STATUT_OPERATEUR_INDISPONIBLE',
                'incident_id' => $incident,
                'paiement' => $paiement->fresh(),
            ], 503);
        }

        return response()->json($paiement->load('commande'));
    }

    private function normaliserTelephone(string $telephone, string $fournisseur): string
    {
        $telephone = ltrim($telephone, '+');

        if ($fournisseur === Paiement::FOURNISSEUR_MTN_MOMO
            && config('services.mtn_momo.target_environment') === 'sandbox'
            && str_starts_with($telephone, '46')) {
            return $telephone;
        }

        return str_starts_with($telephone, '237') ? $telephone : '237'.$telephone;
    }
}
