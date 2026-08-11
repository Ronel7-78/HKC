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
            // Un complement peut representer un accompagnement simple ou mixte,
            // mais une ligne de commande doit toujours en contenir exactement un.
            'items.*.complements' => 'required|array|size:1',
            'items.*.complements.*' => 'exists:complements,id',
            'adresse_livraison' => 'required|string',
            'latitude_client' => 'required|numeric',
            'longitude_client' => 'required|numeric',
        ]);
    }

    private function trouverVendeurEligible(array $items, $lat, $lng)
    {
        $produitIds = collect($items)->pluck('produit_id')->unique();

        // Formule de Haversine utilisee pour calculer la distance en kilometres.
        // La condition WHERE fonctionne avec MySQL et avec SQLite pendant les tests.
        $calculDistance = '( 6371 * acos( cos( radians(?) ) * cos( radians(latitude) ) * cos( radians(longitude) - radians(?) ) + sin( radians(?) ) * sin( radians(latitude) ) ) )';

        return Vendeur::where('statut_compte', 'actif')
            ->where('statut_dispo', 'disponible')
            ->whereHas('produits', function ($q) use ($produitIds) {
                $q->whereIn('produits.id', $produitIds)
                    ->where('vendeur_produits.statut', 'disponible');
            }, '=', $produitIds->count())
            ->selectRaw("vendeurs.*, {$calculDistance} AS distance", [$lat, $lng, $lat])
            ->whereRaw("{$calculDistance} < ?", [$lat, $lng, $lat, 5])
            ->orderBy('distance')
            ->first();
    }

    private function calculerTotaux(array $items)
    {
        $sousTotal = 0;
        $lignes = [];

        foreach ($items as $item) {
            $produit = Produit::findOrFail($item['produit_id']);

            // Le complement doit exister dans la liste autorisee du produit.
            $complementsAutorises = $produit->complements()->pluck('complements.id')->toArray();
            foreach ($item['complements'] as $compId) {
                if (! in_array($compId, $complementsAutorises)) {
                    abort(422, "Le complément choisi n'est pas disponible pour {$produit->nom}");
                }
            }

            $sousTotal += $produit->prix;

            $lignes[] = [
                'produit_id' => $produit->id,
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
            return response()->json(['message' => 'Aucun vendeur disponible ne peut honorer cette commande actuellement'], 422);
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

        $vendeur = $this->trouverVendeurEligible(
            $request->items, $request->latitude_client, $request->longitude_client
        );

        if (! $vendeur) {
            return response()->json(['message' => "Le vendeur proposé n'est plus disponible, relance une recherche"], 422);
        }

        [$sousTotal, $lignes] = $this->calculerTotaux($request->items);
        $fraisLivraison = 300;

        $commande = DB::transaction(function () use ($client, $vendeur, $lignes, $sousTotal, $fraisLivraison, $request) {
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
                    'quantite' => 1,
                    'prix_unitaire' => $ligne['prix_unitaire'],
                ]);
                $item->complements()->attach($ligne['complements']);
            }

            return $commande;
        });

        return response()->json([
            'message' => 'Commande créée, en attente de paiement',
            'commande' => $commande->load('items.complements', 'vendeur'),
        ], 201);
    }

    // Utile pour tester l'étape suivante (paiement) : lister mes commandes
    public function index(Request $request)
    {
        $client = $request->user()->client;

        return response()->json(
            $client->commandes()->with('items.complements', 'vendeur')->latest()->get()
        );
    }
}
