<?php

// app/Http/Controllers/Api/CommandeController.php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Commande;
use App\Models\CommandeItem;
use App\Models\Produit;
use App\Models\Vendeur;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

class CommandeController extends Controller
{
    private function validerPanier(Request $request)
    {
        return Validator::make($request->all(), [
            'items' => 'required|array|min:1',
            'items.*.produit_id' => 'required|exists:produits,id',
            'items.*.quantite' => 'sometimes|integer|min:1|max:20',
            // Un complement peut representer un accompagnement simple ou mixte,
            // mais une ligne de commande doit toujours en contenir exactement un.
            'items.*.complements' => 'required|array|size:1',
            'items.*.complements.*' => 'exists:complements,id',
            'adresse_livraison' => 'required|string',
            'latitude_client' => 'required|numeric',
            'longitude_client' => 'required|numeric',
            // Facultatif pour conserver les anciens clients. Lorsqu'il est fourni,
            // il doit correspondre au vendeur retourne par l'apercu.
            'vendeur_id' => 'sometimes|integer|exists:vendeurs,id',
        ]);
    }

    private function trouverVendeurEligible(array $items, $lat, $lng, ?int $vendeurId = null)
    {
        $produitIds = collect($items)->pluck('produit_id')->unique();

        // Formule de Haversine utilisee pour calculer la distance en kilometres.
        // La condition WHERE fonctionne avec MySQL et avec SQLite pendant les tests.
        $calculDistance = '( 6371 * acos( cos( radians(?) ) * cos( radians(latitude) ) * cos( radians(longitude) - radians(?) ) + sin( radians(?) ) * sin( radians(latitude) ) ) )';

        return Vendeur::when($vendeurId, fn ($query) => $query->whereKey($vendeurId))
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

    /**
     * Reverifie l'eligibilite sous verrou pour qu'un changement de disponibilite
     * entre l'apercu et la creation ne produise pas une mauvaise affectation.
     */
    private function verrouillerVendeurEligible(array $items, $lat, $lng, ?int $vendeurId = null)
    {
        $vendeur = $this->trouverVendeurEligible($items, $lat, $lng, $vendeurId);

        if (! $vendeur) {
            return null;
        }

        Vendeur::whereKey($vendeur->id)->lockForUpdate()->first();

        return $this->trouverVendeurEligible($items, $lat, $lng, $vendeur->id);
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

    public function preview(Request $request)
    {
        $validator = $this->validerPanier($request);
        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $vendeur = $this->trouverVendeurEligible(
            $request->items, $request->latitude_client, $request->longitude_client
        );

        if (! $vendeur) {
            return response()->json([
                'message' => 'Aucun vendeur actif et disponible ne propose actuellement tous les produits demandés.',
                'code' => 'AUCUN_VENDEUR_ELIGIBLE',
            ], 422);
        }

        [$sousTotal, $lignes] = $this->calculerTotaux($request->items);
        $fraisLivraison = 300;

        return response()->json([
            'vendeur' => [
                'id' => $vendeur->id,
                'nom_boutique' => $vendeur->nom_boutique,
                'distance_km' => round($vendeur->distance, 2),
            ],
            'sous_total' => $sousTotal,
            'frais_livraison' => $fraisLivraison,
            'total' => $sousTotal + $fraisLivraison,
        ]);
    }

    public function store(Request $request)
    {
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

        $commande = DB::transaction(function () use ($client, $request) {
            $vendeur = $this->verrouillerVendeurEligible(
                $request->items,
                $request->latitude_client,
                $request->longitude_client,
                $request->integer('vendeur_id') ?: null,
            );

            if (! $vendeur) {
                return null;
            }

            [$sousTotal, $lignes] = $this->calculerTotaux($request->items);
            $fraisLivraison = 300;

            $commande = Commande::create([
                'client_id' => $client->id,
                'vendeur_id' => $vendeur->id,
                'statut' => 'en_attente_paiement',
                'adresse_livraison' => $request->adresse_livraison,
                'latitude_client' => $request->latitude_client,
                'longitude_client' => $request->longitude_client,
                'sous_total' => $sousTotal,
                'frais_livraison' => $fraisLivraison,
                'total' => $sousTotal + $fraisLivraison,
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

            return $commande;
        });

        if (! $commande) {
            $vendeurPropose = $request->filled('vendeur_id');

            return response()->json([
                'message' => $vendeurPropose
                    ? 'Le vendeur sélectionné n’est plus éligible. Relancez l’aperçu de la commande.'
                    : 'Aucun vendeur actif et disponible ne propose actuellement tous les produits demandés.',
                'code' => $vendeurPropose ? 'VENDEUR_DEVENU_INELIGIBLE' : 'AUCUN_VENDEUR_ELIGIBLE',
            ], 422);
        }

        return response()->json([
            'message' => 'Commande créée, en attente de paiement',
            'commande' => $commande->load('items.complements', 'vendeur'),
        ], 201);
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
        $client = $request->user()->client;

        if (! $client) {
            return response()->json([
                'message' => 'Ce compte n\'a pas de profil client associé.',
            ], 403);
        }

        if ($commande->client_id !== $client->id) {
            return response()->json([
                'message' => 'Cette commande n\'appartient pas à ce client.',
            ], 403);
        }

        return response()->json(
            $commande->load('items.produit', 'items.complements', 'vendeur')
        );
    }

    /**
     * Annule une commande du client avant le debut de sa preparation.
     */
    public function annuler(Request $request, Commande $commande)
    {
        $client = $request->user()->client;

        if (! $client) {
            return response()->json([
                'message' => 'Ce compte n\'a pas de profil client associé.',
            ], 403);
        }

        if ($commande->client_id !== $client->id) {
            return response()->json([
                'message' => 'Cette commande n\'appartient pas à ce client.',
            ], 403);
        }

        if (! $commande->peutEtreAnnuleeParClient()) {
            return response()->json([
                'message' => "La commande ne peut plus être annulée par le client depuis le statut {$commande->statut}.",
                'code' => 'ANNULATION_CLIENT_IMPOSSIBLE',
            ], 422);
        }

        $commande->update(['statut' => Commande::STATUT_ANNULEE]);

        return response()->json([
            'message' => 'Commande annulée.',
            'commande' => $commande->fresh()->load('items.produit', 'items.complements', 'vendeur'),
        ]);
    }
}
