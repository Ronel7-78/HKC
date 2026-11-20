<?php

// app/Http/Controllers/Api/CommandeController.php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Commande;
use App\Models\CommandeItem;
use App\Models\Produit;
use App\Models\Vendeur;
use App\Services\DeliveryPricingService;
use App\Services\NotificationService;
use App\Services\OnlinePaymentPricingService;
use Illuminate\Contracts\Cache\LockTimeoutException;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;

class CommandeController extends Controller
{
    private function validerPanier(Request $request)
    {
        return Validator::make($request->all(), [
            'items' => 'required|array|min:1|max:20',
            'items.*.produit_id' => 'required|exists:produits,id',
            'items.*.quantite' => 'sometimes|integer|min:1|max:20',
            // Un complement peut representer un accompagnement simple ou mixte,
            // mais une ligne de commande doit toujours en contenir exactement un.
            'items.*.complements' => 'required|array|size:1',
            'items.*.complements.*' => 'exists:complements,id',
            'adresse_livraison' => 'required|string|max:255',
            'latitude_client' => 'required|numeric|between:-90,90',
            'longitude_client' => 'required|numeric|between:-180,180',
            'livraison_express' => 'sometimes|boolean',
            'mode_remise' => 'sometimes|in:livraison',
            // Facultatif pour conserver les anciens clients. Lorsqu'il est fourni,
            // il doit correspondre au vendeur retourne par l'apercu.
            'vendeur_id' => 'sometimes|integer|exists:vendeurs,id',
        ]);
    }

    private function trouverVendeurEligible(
        array $items,
        $lat,
        $lng,
        ?int $vendeurId = null,
        bool $express = false,
    ) {
        $produitIds = collect($items)->pluck('produit_id')->unique();

        // Formule de Haversine utilisee pour calculer la distance en kilometres.
        // La condition WHERE fonctionne avec MySQL et avec SQLite pendant les tests.
        $calculDistance = '( 6371 * acos( cos( radians(?) ) * cos( radians(latitude) ) * cos( radians(longitude) - radians(?) ) + sin( radians(?) ) * sin( radians(latitude) ) ) )';

        return Vendeur::when($vendeurId, fn ($query) => $query->whereKey($vendeurId))
            ->when($express, fn ($query) => $query
                ->where('type_vendeur', Vendeur::TYPE_POINT_FIXE)
                ->where('accepte_express', true))
            ->when(! $express, fn ($query) => $query
                ->where('type_vendeur', Vendeur::TYPE_AMBULANT))
            ->whereNotNull('latitude')
            ->whereNotNull('longitude')
            ->where('statut_compte', 'actif')
            ->where('statut_dispo', 'disponible')
            ->whereHas('produits', function ($q) use ($produitIds) {
                $q->whereIn('produits.id', $produitIds)
                    ->where('vendeur_produits.statut', 'disponible');
            }, '=', $produitIds->count())
            ->selectRaw("vendeurs.*, {$calculDistance} AS distance", [$lat, $lng, $lat])
            ->orderBy('distance')
            ->first();
    }

    private function calculerTotaux(array $items)
    {
        $sousTotal = 0;
        $lignes = [];

        foreach ($items as $item) {
            $produit = Produit::findOrFail($item['produit_id']);
            $quantite = (int) ($item['quantite'] ?? 1);

            // Le complement doit exister dans la liste autorisee du produit.
            $complementsAutorises = $produit->complements()->pluck('complements.id')->toArray();
            foreach ($item['complements'] as $compId) {
                if (! in_array($compId, $complementsAutorises)) {
                    abort(422, "Le complément choisi n'est pas disponible pour {$produit->nom}");
                }
            }

            $sousTotal += $produit->prix * $quantite;

            $lignes[] = [
                'produit_id' => $produit->id,
                'quantite' => $quantite,
                'prix_unitaire' => $produit->prix,
                'complements' => $item['complements'],
            ];
        }

        return [$sousTotal, $lignes];
    }

    public function preview(
        Request $request,
        DeliveryPricingService $delivery,
        OnlinePaymentPricingService $paymentPricing,
    ) {
        $validator = $this->validerPanier($request);
        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $express = $request->boolean('livraison_express');
        $modeRemise = 'livraison';
        $vendeurId = $express ? null : ($request->integer('vendeur_id') ?: null);
        $vendeur = $this->trouverVendeurEligible(
            $request->items,
            $request->latitude_client,
            $request->longitude_client,
            $vendeurId,
            $express,
        );

        if (! $vendeur) {
            return response()->json([
                'message' => 'Aucun vendeur actif et disponible ne propose actuellement tous les produits demandés.',
                'code' => 'AUCUN_VENDEUR_ELIGIBLE',
            ], 422);
        }

        [$sousTotal, $lignes] = $this->calculerTotaux($request->items);
        $distanceKm = $delivery->displayedDistance((float) $vendeur->distance);
        $livraisonExpress = $express;
        $fraisLivraison = $delivery->feeForExpress($livraisonExpress);
        $tarification = $paymentPricing->totals($sousTotal, $fraisLivraison);

        return response()->json([
            'vendeur' => [
                'id' => $vendeur->id,
                'nom_boutique' => $vendeur->nom_boutique,
                'distance_km' => $distanceKm,
            ],
            'sous_total' => $sousTotal,
            'frais_livraison' => $fraisLivraison,
            'frais_paiement' => $tarification['frais_paiement'],
            'total' => $tarification['total'],
            'livraison_express' => $livraisonExpress,
            'mode_remise' => $modeRemise,
            'livraison_gratuite' => ! $livraisonExpress,
            'politique_livraison' => 'Livraison standard : 0 FCFA. Livraison express prioritaire : 500 FCFA.',
        ]);
    }

    public function store(
        Request $request,
        DeliveryPricingService $delivery,
        OnlinePaymentPricingService $paymentPricing,
    ) {
        $validator = $this->validerPanier($request);
        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $client = $request->user()->client;

        if (! $client) {
            return response()->json([
                'message' => 'Seul un compte client peut passer une commande. Ce compte n\'a pas de profil client associé.',
            ], 403);
        }

        $idempotencyKey = $this->idempotencyKey($request);

        // Les prix et les complements sont figes dans la commande. Les lire
        // avant la transaction raccourcit celle-ci et evite de faire patienter
        // toutes les commandes qui visent le meme vendeur.
        [$sousTotal, $lignes] = $this->calculerTotaux($request->items);

        // Une nouvelle tentative manuelle avec la meme cle doit toujours
        // retourner la commande originale, sans recreer les lignes ni notifier.
        $commandeExistante = Commande::query()
            ->where('client_id', $client->id)
            ->where('idempotency_key', $idempotencyKey)
            ->first();

        if ($commandeExistante) {
            return $this->reponseCommande($commandeExistante, false);
        }

        // Les doublons reseau sont serialises avant MySQL. Ainsi, dix clics
        // simultanes portant la meme cle ne se battent pas pour verrouiller le
        // vendeur ; ils recoivent tous la commande gagnee par la premiere
        // requete. La contrainte unique en base reste la derniere barriere.
        $lock = Cache::lock(
            'commande:idempotency:'.hash('sha256', $client->id.'|'.$idempotencyKey),
            30,
        );

        try {
            [$commande, $cree] = $lock->block(10, function () use ($client, $request, $delivery, $paymentPricing, $idempotencyKey, $sousTotal, $lignes) {
                return DB::transaction(function () use ($client, $request, $delivery, $paymentPricing, $idempotencyKey, $sousTotal, $lignes) {
                    $existante = Commande::query()
                        ->where('client_id', $client->id)
                        ->where('idempotency_key', $idempotencyKey)
                        ->lockForUpdate()
                        ->first();

                    if ($existante) {
                        return [$existante, false];
                    }

                    $express = $request->boolean('livraison_express');
                    $modeRemise = 'livraison';
                    $vendeurId = $express ? null : ($request->integer('vendeur_id') ?: null);
                    // Aucune quantite de stock n'est reservee a ce stade : un
                    // verrou exclusif sur la ligne vendeur ne protege donc
                    // aucune ressource partagee, mais serialise inutilement
                    // toutes ses commandes. Cette recherche fraiche garantit
                    // toutefois que le vendeur est actif/disponible au moment
                    // de creer la commande.
                    $vendeur = $this->trouverVendeurEligible(
                        $request->items,
                        $request->latitude_client,
                        $request->longitude_client,
                        $vendeurId,
                        $express,
                    );

                    if (! $vendeur) {
                        return [null, false];
                    }

                    $distanceKm = $delivery->displayedDistance((float) $vendeur->distance);
                    $livraisonExpress = $express;
                    $fraisLivraison = $delivery->feeForExpress($livraisonExpress);
                    $tarification = $paymentPricing->totals($sousTotal, $fraisLivraison);

                    $commande = Commande::create([
                        'client_id' => $client->id,
                        'vendeur_id' => $vendeur->id,
                        'idempotency_key' => $idempotencyKey,
                        'statut' => 'en_attente_paiement',
                        'adresse_livraison' => $request->adresse_livraison,
                        'latitude_client' => $request->latitude_client,
                        'longitude_client' => $request->longitude_client,
                        'distance_km' => $distanceKm,
                        'livraison_express' => $livraisonExpress,
                        'mode_remise' => $modeRemise,
                        'sous_total' => $sousTotal,
                        'frais_livraison' => $fraisLivraison,
                        'frais_paiement' => $tarification['frais_paiement'],
                        'total' => $tarification['total'],
                    ]);

                    foreach ($lignes as $ligne) {
                        $item = CommandeItem::create([
                            'commande_id' => $commande->id,
                            'produit_id' => $ligne['produit_id'],
                            'quantite' => $ligne['quantite'],
                            'prix_unitaire' => $ligne['prix_unitaire'],
                        ]);
                        $item->complements()->attach($ligne['complements']);
                    }

                    return [$commande, true];
                }, 5);
            });
        } catch (LockTimeoutException) {
            // Le premier traitement est encore en cours. S'il a fini juste
            // avant notre lecture, renvoyer sa commande ; sinon le client
            // conserve sa cle et peut reessayer sans risque de doublon.
            $commande = Commande::query()
                ->where('client_id', $client->id)
                ->where('idempotency_key', $idempotencyKey)
                ->first();

            if ($commande) {
                return $this->reponseCommande($commande, false);
            }

            return response()->json([
                'message' => 'Votre commande est en cours de traitement. Réessayez dans quelques instants.',
                'code' => 'COMMANDE_EN_COURS',
            ], 409);
        } catch (UniqueConstraintViolationException $exception) {
            // Deux requetes avec la meme cle peuvent franchir la premiere
            // lecture avant que la premiere transaction n'ait valide son
            // insertion. La contrainte unique est l'arbitre final : relire
            // alors la commande gagnee et la renvoyer comme une reutilisation.
            $commande = Commande::query()
                ->where('client_id', $client->id)
                ->where('idempotency_key', $idempotencyKey)
                ->first();

            if (! $commande) {
                throw $exception;
            }

            $cree = false;
        }

        if (! $commande) {
            $vendeurPropose = $request->filled('vendeur_id');

            return response()->json([
                'message' => $vendeurPropose
                    ? 'Le vendeur sélectionné n’est plus éligible. Relancez l’aperçu de la commande.'
                    : 'Aucun vendeur actif et disponible ne propose actuellement tous les produits demandés.',
                'code' => $vendeurPropose ? 'VENDEUR_DEVENU_INELIGIBLE' : 'AUCUN_VENDEUR_ELIGIBLE',
            ], 422);
        }

        if ($cree) {
            $commande->load('client.user', 'vendeur.user');
            NotificationService::envoyer(
                $commande->client->user,
                'commande_creee',
                'Commande créée',
                "Votre commande {$commande->code_commande} attend maintenant le paiement.",
                ['commande_id' => $commande->id]
            );
            NotificationService::admins(
                'nouvelle_commande',
                'Nouvelle commande',
                "La commande {$commande->code_commande} vient d’être créée.",
                ['commande_id' => $commande->id]
            );
        }

        return $this->reponseCommande($commande, $cree);
    }

    // Utile pour tester l'étape suivante (paiement) : lister mes commandes
    public function index(Request $request)
    {
        $client = $request->user()->client;

        if (! $client) {
            return response()->json([
                'message' => 'Ce compte n\'a pas de profil client associé.',
            ], 403);
        }

        return response()->json(
            $client->commandes()
                ->when(! $request->boolean('masquees'), fn ($query) => $query->whereNull('masquee_client_le'))
                ->with('items.produit', 'items.complements', 'vendeur', 'paiements', 'avis')
                ->latest()
                ->get()
        );
    }

    /**
     * Affiche uniquement une commande appartenant au client authentifie.
     */
    public function show(Request $request, Commande $commande)
    {
        $this->authorize('client', $commande);
        $client = $request->user()->client;

        if (! $client) {
            return response()->json([
                'message' => 'Ce compte n\'a pas de profil client associé.',
            ], 403);
        }

        return response()->json(
            $commande->load('items.produit', 'items.complements', 'vendeur')
        );
    }

    public function masquer(Request $request, Commande $commande)
    {
        $this->authorize('client', $commande);

        if (! in_array($commande->statut, [Commande::STATUT_LIVREE, Commande::STATUT_ANNULEE], true)) {
            return response()->json([
                'message' => 'Seules les commandes terminées peuvent être masquées.',
                'code' => 'COMMANDE_NON_MASQUABLE',
            ], 422);
        }

        $commande->update(['masquee_client_le' => now()]);

        return response()->json(['message' => 'Commande masquée de votre liste.']);
    }

    public function afficher(Request $request, Commande $commande)
    {
        $this->authorize('client', $commande);
        $commande->update(['masquee_client_le' => null]);

        return response()->json(['message' => 'Commande restaurée dans votre liste.']);
    }

    private function idempotencyKey(Request $request): string
    {
        $key = trim((string) $request->header('Idempotency-Key', ''));

        if ($key === '') {
            // Compatibilite temporaire avec les anciennes versions mobiles.
            // Les versions actuelles transmettent toujours une cle stable.
            return (string) Str::uuid();
        }

        abort_unless(preg_match('/^[A-Za-z0-9_-]{16,128}$/', $key) === 1, 422,
            'La clé de sécurité de la commande est invalide. Réessayez.');

        return $key;
    }

    private function reponseCommande(Commande $commande, bool $cree)
    {
        return response()->json([
            'message' => $cree
                ? 'Commande créée, en attente de paiement'
                : 'Cette commande a déjà été enregistrée.',
            'commande' => $commande->load('items.produit', 'items.complements', 'vendeur'),
        ], $cree ? 201 : 200);
    }
}
