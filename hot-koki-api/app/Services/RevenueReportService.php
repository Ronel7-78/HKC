<?php

namespace App\Services;

use App\Models\Paiement;
use App\Models\Vendeur;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;

class RevenueReportService
{
    /** @return array{jour: float, semaine: float, mois: float, total: float, paiements_reussis: int} */
    public function totals(?int $vendeurId = null): array
    {
        $query = $this->successfulPayments($vendeurId);

        return [
            'jour' => (float) (clone $query)->where('confirme_le', '>=', $this->dayStart())->sum('montant'),
            'semaine' => (float) (clone $query)->where('confirme_le', '>=', $this->weekStart())->sum('montant'),
            'mois' => (float) (clone $query)->where('confirme_le', '>=', $this->monthStart())->sum('montant'),
            'total' => (float) (clone $query)->sum('montant'),
            'paiements_reussis' => (clone $query)->count(),
        ];
    }

    /** @return Collection<int, array<string, mixed>> */
    public function byVendor(): Collection
    {
        $revenues = Paiement::query()
            ->join('commandes', 'commandes.id', '=', 'paiements.commande_id')
            ->where('paiements.statut', Paiement::STATUT_REUSSI)
            ->selectRaw('commandes.vendeur_id as vendeur_id')
            ->selectRaw('SUM(CASE WHEN paiements.confirme_le >= ? THEN paiements.montant ELSE 0 END) as jour', [$this->dayStart()])
            ->selectRaw('SUM(CASE WHEN paiements.confirme_le >= ? THEN paiements.montant ELSE 0 END) as semaine', [$this->weekStart()])
            ->selectRaw('SUM(CASE WHEN paiements.confirme_le >= ? THEN paiements.montant ELSE 0 END) as mois', [$this->monthStart()])
            ->selectRaw('SUM(paiements.montant) as total')
            ->selectRaw('COUNT(paiements.id) as paiements_reussis')
            ->groupBy('commandes.vendeur_id')
            ->get()
            ->keyBy('vendeur_id');

        return Vendeur::query()
            ->with('user:id,name')
            ->orderBy('nom_boutique')
            ->get()
            ->map(function (Vendeur $vendeur) use ($revenues): array {
                $revenue = $revenues->get($vendeur->id);

                return [
                    'vendeur_id' => $vendeur->id,
                    'nom_boutique' => $vendeur->nom_boutique,
                    'responsable' => $vendeur->user?->name,
                    'jour' => (float) ($revenue->jour ?? 0),
                    'semaine' => (float) ($revenue->semaine ?? 0),
                    'mois' => (float) ($revenue->mois ?? 0),
                    'total' => (float) ($revenue->total ?? 0),
                    'paiements_reussis' => (int) ($revenue->paiements_reussis ?? 0),
                ];
            });
    }

    private function successfulPayments(?int $vendeurId): Builder
    {
        return Paiement::query()
            ->where('statut', Paiement::STATUT_REUSSI)
            ->when(
                $vendeurId,
                fn (Builder $query, int $id) => $query->whereHas(
                    'commande',
                    fn (Builder $commande) => $commande->where('vendeur_id', $id)
                )
            );
    }

    private function dayStart(): Carbon
    {
        return now()->startOfDay();
    }

    private function weekStart(): Carbon
    {
        return now()->startOfWeek();
    }

    private function monthStart(): Carbon
    {
        return now()->startOfMonth();
    }
}
