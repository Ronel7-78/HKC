<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Commande;
use App\Models\Paiement;
use App\Services\Payments\CamPayService;
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
        $camPayDisponible = config('payments.gateway') === Paiement::PASSERELLE_CAMPAY
            && config('services.campay.enabled')
            && filled(config('services.campay.username'))
            && filled(config('services.campay.password'));

        return response()->json([
            [
                'code' => Paiement::FOURNISSEUR_MTN_MOMO,
                'nom' => 'MTN MoMo',
                'disponible' => $camPayDisponible
                    || (config('payments.gateway') === Paiement::PASSERELLE_DIRECTE
                        && config('services.mtn_momo.enabled')),
                'passerelle' => config('payments.gateway'),
            ],
            [
                'code' => Paiement::FOURNISSEUR_ORANGE_MONEY,
                'nom' => 'Orange Money',
                'disponible' => $camPayDisponible
                    || (config('payments.gateway') === Paiement::PASSERELLE_DIRECTE
                        && config('services.orange_money.enabled')),
                'passerelle' => config('payments.gateway'),
            ],
        ]);
    }

    public function store(
        Request $request,
        Commande $commande,
        CamPayService $camPay,
        MtnMomoService $mtnMomo,
        OrangeMoneyService $orangeMoney,
    ) {
        $this->authorize('client', $commande);
        $client = $request->user()->client;

        $passerelle = (string) config('payments.gateway');
        $telephoneRegex = $passerelle === Paiement::PASSERELLE_DIRECTE
            && $request->input('fournisseur') === Paiement::FOURNISSEUR_MTN_MOMO
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

        if ($passerelle === Paiement::PASSERELLE_CAMPAY
            && (! config('services.campay.enabled')
                || blank(config('services.campay.username'))
                || blank(config('services.campay.password')))) {
            return response()->json([
                'message' => 'Le paiement Mobile Money est temporairement indisponible.',
                'code' => 'CAMPAY_INDISPONIBLE',
            ], 503);
        }

        if ($passerelle === Paiement::PASSERELLE_DIRECTE) {
            $directDisponible = $validated['fournisseur'] === Paiement::FOURNISSEUR_MTN_MOMO
                ? config('services.mtn_momo.enabled')
                : config('services.orange_money.enabled');
            if (! $directDisponible) {
                return response()->json([
                    'message' => 'Ce moyen de paiement est temporairement indisponible.',
                    'code' => $validated['fournisseur'] === Paiement::FOURNISSEUR_ORANGE_MONEY
                        ? 'ORANGE_MONEY_INDISPONIBLE'
                        : 'MTN_MOMO_INDISPONIBLE',
                ], 503);
            }
        }

        $paiement = DB::transaction(function () use ($commande, $validated, $passerelle) {
            $commandeVerrouillee = Commande::whereKey($commande->id)->lockForUpdate()->firstOrFail();

            if ($commandeVerrouillee->statut !== Commande::STATUT_EN_ATTENTE_PAIEMENT) {
                return null;
            }

            $tentativeActive = $commandeVerrouillee->paiements()
                ->whereIn('statut', Paiement::STATUTS_ACTIFS)
                ->where('passerelle', $passerelle)
                ->latest()
                ->first();

            if ($tentativeActive) {
                return $tentativeActive;
            }

            return $commandeVerrouillee->paiements()->create([
                'fournisseur' => $validated['fournisseur'],
                'passerelle' => $passerelle,
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
                if ($paiement->passerelle === Paiement::PASSERELLE_CAMPAY) {
                    $camPay->initier($paiement);
                } else {
                    match ($paiement->fournisseur) {
                        Paiement::FOURNISSEUR_MTN_MOMO => $mtnMomo->initier($paiement),
                        Paiement::FOURNISSEUR_ORANGE_MONEY => $orangeMoney->initier($paiement),
                    };
                }
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
            'paiement' => $paiement->load('commande'),
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
        CamPayService $camPay,
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

        $tentativesMax = match (true) {
            $paiement->passerelle === Paiement::PASSERELLE_CAMPAY => config('services.campay.poll_max_attempts'),
            $paiement->fournisseur === Paiement::FOURNISSEUR_ORANGE_MONEY => config('services.orange_money.poll_max_attempts'),
            default => config('services.mtn_momo.poll_max_attempts'),
        };
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
            $paiement = match ($paiement->passerelle) {
                Paiement::PASSERELLE_CAMPAY => $camPay->synchroniser($paiement),
                default => match ($paiement->fournisseur) {
                    Paiement::FOURNISSEUR_MTN_MOMO => $mtnMomo->synchroniser($paiement),
                    Paiement::FOURNISSEUR_ORANGE_MONEY => $orangeMoney->synchroniser($paiement),
                    default => throw new RuntimeException('Fournisseur de paiement inconnu.'),
                },
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

        if (config('payments.gateway') === Paiement::PASSERELLE_DIRECTE
            && $fournisseur === Paiement::FOURNISSEUR_MTN_MOMO
            && config('services.mtn_momo.target_environment') === 'sandbox'
            && str_starts_with($telephone, '46')) {
            return $telephone;
        }

        return str_starts_with($telephone, '237') ? $telephone : '237'.$telephone;
    }
}
