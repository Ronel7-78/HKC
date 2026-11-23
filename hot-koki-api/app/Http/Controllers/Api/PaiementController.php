<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Commande;
use App\Models\Paiement;
use App\Services\Payments\CamPayService;
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
        $camPayDisponible = config('services.campay.enabled')
            && filled(config('services.campay.username'))
            && filled(config('services.campay.password'));

        return response()->json([
            [
                'code' => Paiement::FOURNISSEUR_MTN_MOMO,
                'nom' => 'MTN MoMo',
                'disponible' => $camPayDisponible,
                'passerelle' => Paiement::PASSERELLE_CAMPAY,
            ],
            [
                'code' => Paiement::FOURNISSEUR_ORANGE_MONEY,
                'nom' => 'Orange Money',
                'disponible' => $camPayDisponible,
                'passerelle' => Paiement::PASSERELLE_CAMPAY,
            ],
        ]);
    }

    public function store(
        Request $request,
        Commande $commande,
        CamPayService $camPay,
    ) {
        $this->authorize('client', $commande);

        $validated = $request->validate([
            'fournisseur' => ['required', Rule::in([
                Paiement::FOURNISSEUR_MTN_MOMO,
                Paiement::FOURNISSEUR_ORANGE_MONEY,
            ])],
            'telephone' => ['required', 'string', 'max:20', 'regex:/^(?:\+?237)?6\d{8}$/'],
        ], [
            'telephone.regex' => 'Le numéro doit être un numéro camerounais valide.',
        ]);

        if (! config('services.campay.enabled')
            || blank(config('services.campay.username'))
            || blank(config('services.campay.password'))) {
            return response()->json([
                'message' => 'Le paiement Mobile Money est temporairement indisponible.',
                'code' => 'CAMPAY_INDISPONIBLE',
            ], 503);
        }

        $idempotencyKey = $this->idempotencyKey($request);

        [$paiement, $cree] = DB::transaction(function () use ($commande, $validated, $idempotencyKey) {
            $commandeVerrouillee = Commande::whereKey($commande->id)->lockForUpdate()->firstOrFail();

            if ($commandeVerrouillee->statut !== Commande::STATUT_EN_ATTENTE_PAIEMENT) {
                return [null, false];
            }

            $tentativeIdempotente = $commandeVerrouillee->paiements()
                ->where('idempotency_key', $idempotencyKey)
                ->first();

            if ($tentativeIdempotente) {
                return [$tentativeIdempotente, false];
            }

            $tentativeActive = $commandeVerrouillee->paiements()
                ->whereIn('statut', Paiement::STATUTS_ACTIFS)
                ->where('passerelle', Paiement::PASSERELLE_CAMPAY)
                ->latest()
                ->first();

            if ($tentativeActive) {
                return [$tentativeActive, false];
            }

            return [$commandeVerrouillee->paiements()->create([
                'idempotency_key' => $idempotencyKey,
                'fournisseur' => $validated['fournisseur'],
                'passerelle' => Paiement::PASSERELLE_CAMPAY,
                'telephone' => $this->normaliserTelephone($validated['telephone']),
                'montant' => $commandeVerrouillee->total,
                'devise' => 'XAF',
                'statut' => Paiement::STATUT_INITIE,
            ]), true];
        });

        if (! $paiement) {
            return response()->json([
                'message' => 'Cette commande n’est plus en attente de paiement.',
                'code' => 'COMMANDE_NON_PAYABLE',
            ], 422);
        }

        // Une demande externe n'est envoyee qu'une seule fois. Si le client
        // perd le reseau puis reessaie, il recupere la tentative existante.
        if ($cree) {
            try {
                $camPay->initier($paiement);
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
            'message' => $cree
                ? 'Demande de paiement envoyée à l’opérateur.'
                : 'Une demande de paiement est déjà en cours.',
            'paiement' => $paiement->load('commande'),
        ], $cree ? 201 : 200);
    }

    public function show(Request $request, Paiement $paiement)
    {
        $this->authorize('client', $paiement);

        return response()->json($paiement->load('commande'));
    }

    private function idempotencyKey(Request $request): string
    {
        $key = trim((string) $request->header('Idempotency-Key', ''));

        if ($key === '') {
            // Compatibilite avec les versions installees avant l'ajout de la
            // cle. Les applications a jour envoient une cle stable.
            return (string) Str::uuid();
        }

        abort_unless(preg_match('/^[A-Za-z0-9_-]{16,128}$/', $key) === 1, 422,
            'La clé de sécurité du paiement est invalide. Réessayez.');

        return $key;
    }

    public function synchroniser(
        Request $request,
        Paiement $paiement,
        CamPayService $camPay,
    ) {
        $this->authorize('client', $paiement);

        if ($paiement->prochaine_verification_le?->isFuture()) {
            return response()->json([
                'message' => 'La prochaine vérification est temporairement différée.',
                'paiement' => $paiement,
            ], 202);
        }

        $tentativesMax = config('services.campay.poll_max_attempts');
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
            $paiement = $camPay->synchroniser($paiement);
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

    private function normaliserTelephone(string $telephone): string
    {
        $telephone = ltrim($telephone, '+');

        return str_starts_with($telephone, '237') ? $telephone : '237'.$telephone;
    }
}
