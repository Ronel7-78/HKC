<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Relations\Relation;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Validation\Rule;

class NotificationController extends Controller
{
    private const TYPES_PAR_CATEGORIE = [
        'commandes' => ['commande_creee', 'nouvelle_commande', 'commande_annulee', 'statut_commande'],
        'paiements' => ['paiement_reussi', 'paiement_echoue'],
        'avis' => ['nouvel_avis'],
        'compte' => ['compte_vendeur_cree', 'statut_compte'],
    ];

    private const CATEGORIES_PAR_ROLE = [
        'client' => ['commandes', 'paiements', 'compte'],
        'vendeur' => ['commandes', 'avis', 'compte'],
        'admin' => ['commandes', 'paiements', 'avis', 'compte', 'systeme'],
    ];

    public function index(Request $request)
    {
        $categories = self::CATEGORIES_PAR_ROLE[$request->user()->role] ?? array_keys(self::TYPES_PAR_CATEGORIE);
        $filtres = $request->validate([
            'statut' => ['sometimes', Rule::in(['toutes', 'non_lues', 'lues'])],
            'categorie' => ['sometimes', Rule::in($categories)],
            'periode' => ['sometimes', Rule::in(['aujourdhui', '7j', '30j', 'archives'])],
            'recherche' => ['sometimes', 'string', 'max:100'],
            'page' => ['sometimes', 'integer', 'min:1'],
            'par_page' => ['sometimes', 'integer', 'min:1', 'max:50'],
        ]);

        $requete = $request->user()->notifications()->latest();
        $this->appliquerStatut($requete, $filtres['statut'] ?? 'toutes');
        $this->appliquerCategorie($requete, $filtres['categorie'] ?? null);
        $this->appliquerPeriode($requete, $filtres['periode'] ?? null);
        $this->appliquerRecherche($requete, $filtres['recherche'] ?? null);

        $notifications = $requete->paginate($filtres['par_page'] ?? 20);

        return response()->json([
            'notifications' => $notifications->items(),
            'non_lues' => $request->user()->unreadNotifications()->count(),
            'pagination' => [
                'page' => $notifications->currentPage(),
                'par_page' => $notifications->perPage(),
                'derniere_page' => $notifications->lastPage(),
                'total' => $notifications->total(),
                'a_plus' => $notifications->hasMorePages(),
            ],
            'filtres' => [
                'statuts' => ['toutes', 'non_lues', 'lues'],
                'periodes' => ['aujourdhui', '7j', '30j', 'archives'],
                'categories' => $this->categoriesAvecCompteurs($request, $categories),
            ],
        ]);
    }

    public function marquerLue(Request $request, string $notification)
    {
        $item = $request->user()->notifications()->whereKey($notification)->firstOrFail();
        $item->markAsRead();

        return response()->json(['message' => 'Notification marquée comme lue.']);
    }

    public function toutMarquerLu(Request $request)
    {
        $request->user()->unreadNotifications->markAsRead();

        return response()->json(['message' => 'Toutes les notifications ont été lues.']);
    }

    private function appliquerStatut(Builder|Relation $requete, string $statut): void
    {
        if ($statut === 'non_lues') {
            $requete->whereNull('read_at');
        } elseif ($statut === 'lues') {
            $requete->whereNotNull('read_at');
        }
    }

    private function appliquerCategorie(Builder|Relation $requete, ?string $categorie): void
    {
        if (! $categorie) {
            return;
        }

        $typesConnus = array_merge(...array_values(self::TYPES_PAR_CATEGORIE));
        if ($categorie === 'systeme') {
            $requete->whereNotIn('data->type', $typesConnus);

            return;
        }

        $requete->whereIn('data->type', self::TYPES_PAR_CATEGORIE[$categorie]);
    }

    private function appliquerPeriode(Builder|Relation $requete, ?string $periode): void
    {
        match ($periode) {
            'aujourdhui' => $requete->whereDate('created_at', Carbon::today()),
            '7j' => $requete->where('created_at', '>=', now()->subDays(7)),
            '30j' => $requete->where('created_at', '>=', now()->subDays(30)),
            'archives' => $requete->where('created_at', '<', now()->subDays(30)),
            default => null,
        };
    }

    private function appliquerRecherche(Builder|Relation $requete, ?string $recherche): void
    {
        if (! $recherche) {
            return;
        }

        $terme = '%'.addcslashes($recherche, '%_\\').'%';
        $requete->where(function (Builder $sousRequete) use ($terme) {
            $sousRequete
                ->where('data->titre', 'like', $terme)
                ->orWhere('data->message', 'like', $terme)
                ->orWhere('data', 'like', $terme);
        });
    }

    private function categoriesAvecCompteurs(Request $request, array $categories): array
    {
        return collect($categories)->map(function (string $categorie) use ($request) {
            $requete = $request->user()->notifications();
            $this->appliquerCategorie($requete, $categorie);

            return [
                'id' => $categorie,
                'total' => (clone $requete)->count(),
                'non_lues' => (clone $requete)->whereNull('read_at')->count(),
            ];
        })->values()->all();
    }
}
