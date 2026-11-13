<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Commande;
use App\Models\Produit;
use App\Models\User;
use App\Models\Vendeur;
use App\Services\RevenueReportService;

class DashboardController extends Controller
{
    public function __invoke(RevenueReportService $revenueReport)
    {
        $revenus = $revenueReport->totals();

        return response()->json([
            'statistiques' => [
                'vendeurs_actifs' => Vendeur::where('statut_compte', 'actif')->count(),
                'commandes_du_jour' => Commande::whereDate('created_at', today())->count(),
                'chiffre_affaires_du_jour' => $revenus['jour'],
                'utilisateurs' => User::count(),
                'produits' => Produit::count(),
            ],
            'revenus' => $revenus,
            'revenus_par_vendeur' => $revenueReport->byVendor(),
            'vendeurs_recents' => Vendeur::with('user')->latest()->limit(5)->get(),
            'commandes_recentes' => Commande::with('client.user', 'vendeur')->latest()->limit(5)->get(),
        ]);
    }

    public function commandes()
    {
        return response()->json(
            Commande::with('client.user', 'vendeur', 'items.produit', 'paiements')
                ->latest()
                ->paginate(30)
        );
    }

    public function utilisateurs()
    {
        $maintenant = now();
        $total = $this->compterUtilisateurs();

        return response()->json([
            'global' => $total,
            'periodes' => [
                'semaine' => $this->statistiquesPeriode(
                    $maintenant->copy()->startOfWeek(),
                    $maintenant,
                    $maintenant->copy()->subWeek()->startOfWeek(),
                    $maintenant->copy()->subWeek(),
                ),
                'mois' => $this->statistiquesPeriode(
                    $maintenant->copy()->startOfMonth(),
                    $maintenant,
                    $maintenant->copy()->subMonth()->startOfMonth(),
                    $maintenant->copy()->subMonth(),
                ),
                'total' => [
                    ...$total,
                    'precedent' => null,
                    'evolution_pourcentage' => null,
                ],
            ],
        ]);
    }

    /**
     * @return array{total: int, clients: int, vendeurs: int, administrateurs: int}
     */
    private function compterUtilisateurs($debut = null, $fin = null): array
    {
        $query = User::query();
        if ($debut !== null && $fin !== null) {
            $query->whereBetween('created_at', [$debut, $fin]);
        }

        $parRole = $query
            ->selectRaw('role, count(*) as total')
            ->groupBy('role')
            ->pluck('total', 'role');

        $clients = (int) ($parRole['client'] ?? 0);
        $vendeurs = (int) ($parRole['vendeur'] ?? 0);
        $administrateurs = (int) ($parRole['admin'] ?? 0);

        return [
            'total' => $clients + $vendeurs + $administrateurs,
            'clients' => $clients,
            'vendeurs' => $vendeurs,
            'administrateurs' => $administrateurs,
        ];
    }

    private function statistiquesPeriode($debut, $fin, $debutPrecedent, $finPrecedent): array
    {
        $courant = $this->compterUtilisateurs($debut, $fin);
        $precedent = $this->compterUtilisateurs($debutPrecedent, $finPrecedent);
        $base = $precedent['total'];

        return [
            ...$courant,
            'precedent' => $precedent['total'],
            'evolution_pourcentage' => $base === 0
                ? null
                : round((($courant['total'] - $base) / $base) * 100, 1),
        ];
    }
}
