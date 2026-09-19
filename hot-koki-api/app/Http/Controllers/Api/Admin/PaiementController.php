<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Paiement;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class PaiementController extends Controller
{
    public function index(Request $request)
    {
        $validated = $this->validerFiltres($request, true);
        $query = $this->requeteFiltree($validated)->latest();

        $paiements = $query->paginate($validated['par_page'] ?? 30)->withQueryString();
        $paiements->through(fn (Paiement $paiement) => $this->presenter($paiement));

        return response()->json($paiements);
    }

    public function export(Request $request)
    {
        $validated = $this->validerFiltres($request);
        $filename = 'transactions-hot-koki-'.now()->format('Y-m-d-His').'.csv';

        return response()->streamDownload(function () use ($validated): void {
            $output = fopen('php://output', 'wb');
            fwrite($output, "\xEF\xBB\xBF");
            fputcsv($output, [
                'Référence Hot Koki',
                'Référence opérateur',
                'Opérateur',
                'Commande',
                'Client',
                'Vendeur',
                'Téléphone masqué',
                'Montant payé',
                'Devise',
                'Statut',
                'Code erreur',
                'Date initiation',
                'Date confirmation',
                'Date création',
            ], ';');

            $this->requeteFiltree($validated)
                ->orderBy('id')
                ->chunkById(500, function ($paiements) use ($output): void {
                    foreach ($paiements as $paiement) {
                        $commande = $paiement->commande;
                        fputcsv($output, array_map($this->securiserCelluleCsv(...), [
                            $paiement->public_id,
                            $paiement->reference_operateur,
                            $paiement->fournisseur === Paiement::FOURNISSEUR_ORANGE_MONEY ? 'Orange Money' : 'MTN MoMo',
                            $commande?->public_id,
                            $commande?->client?->user?->name,
                            $commande?->vendeur?->nom_boutique,
                            $paiement->telephone_masque,
                            $paiement->montant,
                            $paiement->devise,
                            $paiement->statut,
                            $paiement->code_erreur,
                            $paiement->initie_le?->format('d/m/Y H:i:s'),
                            $paiement->confirme_le?->format('d/m/Y H:i:s'),
                            $paiement->created_at?->format('d/m/Y H:i:s'),
                        ]), ';');
                    }
                });

            fclose($output);
        }, $filename, [
            'Content-Type' => 'text/csv; charset=UTF-8',
            'Cache-Control' => 'private, no-store, max-age=0',
            'X-Content-Type-Options' => 'nosniff',
        ]);
    }

    private function validerFiltres(Request $request, bool $avecPagination = false): array
    {
        return $request->validate([
            'fournisseur' => ['nullable', Rule::in([
                Paiement::FOURNISSEUR_MTN_MOMO,
                Paiement::FOURNISSEUR_ORANGE_MONEY,
            ])],
            'statut' => ['nullable', Rule::in([
                Paiement::STATUT_INITIE,
                Paiement::STATUT_EN_ATTENTE,
                Paiement::STATUT_REUSSI,
                Paiement::STATUT_ECHOUE,
                Paiement::STATUT_EXPIRE,
                Paiement::STATUT_ANNULE,
            ])],
            'vendeur' => ['nullable', 'uuid'],
            'du' => ['nullable', 'date'],
            'au' => ['nullable', 'date', 'after_or_equal:du'],
            'montant_min' => ['nullable', 'numeric', 'min:0'],
            'montant_max' => ['nullable', 'numeric', 'gte:montant_min'],
            'recherche' => ['nullable', 'string', 'max:255'],
            'par_page' => $avecPagination
                ? ['nullable', 'integer', 'min:10', 'max:100']
                : ['prohibited'],
        ]);
    }

    private function requeteFiltree(array $validated): Builder
    {
        return Paiement::query()
            ->with([
                'commande:id,public_id,client_id,vendeur_id,total,frais_livraison,statut',
                'commande.client:id,user_id',
                'commande.client.user:id,name,email',
                'commande.vendeur:id,public_id,nom_boutique',
            ])
            ->when($validated['fournisseur'] ?? null, fn (Builder $query, string $value) => $query->where('fournisseur', $value))
            ->when($validated['statut'] ?? null, fn (Builder $query, string $value) => $query->where('statut', $value))
            ->when($validated['vendeur'] ?? null, fn (Builder $query, string $value) => $query->whereHas(
                'commande.vendeur',
                fn (Builder $vendeur) => $vendeur->where('public_id', $value)
            ))
            ->when($validated['du'] ?? null, fn (Builder $query, string $value) => $query->whereDate('created_at', '>=', $value))
            ->when($validated['au'] ?? null, fn (Builder $query, string $value) => $query->whereDate('created_at', '<=', $value))
            ->when(isset($validated['montant_min']), fn (Builder $query) => $query->where('montant', '>=', $validated['montant_min']))
            ->when(isset($validated['montant_max']), fn (Builder $query) => $query->where('montant', '<=', $validated['montant_max']))
            ->when($validated['recherche'] ?? null, function (Builder $query, string $value): void {
                $query->where(function (Builder $search) use ($value): void {
                    $search->where('public_id', 'like', "%{$value}%")
                        ->orWhere('reference_operateur', 'like', "%{$value}%")
                        ->orWhereHas('commande', fn (Builder $commande) => $commande
                            ->where('public_id', 'like', "%{$value}%")
                            ->orWhereHas('vendeur', fn (Builder $vendeur) => $vendeur
                                ->where('nom_boutique', 'like', "%{$value}%"))
                            ->orWhereHas('client.user', fn (Builder $user) => $user
                                ->where('name', 'like', "%{$value}%")
                                ->orWhere('email', 'like', "%{$value}%")));
                });
            });
    }

    public function show(Paiement $paiement)
    {
        $paiement->load([
            'commande.client.user:id,name,email',
            'commande.vendeur:id,public_id,nom_boutique',
            'evenements',
        ]);

        return response()->json([
            ...$this->presenter($paiement),
            'message_erreur' => $paiement->message_erreur,
            'evenements' => $paiement->evenements->map(fn ($evenement) => [
                'ancien_statut' => $evenement->ancien_statut,
                'nouveau_statut' => $evenement->nouveau_statut,
                'source' => $evenement->source,
                'code' => $evenement->code,
                'message' => $evenement->message,
                'date' => $evenement->created_at,
            ])->values(),
        ]);
    }

    private function presenter(Paiement $paiement): array
    {
        $commande = $paiement->commande;

        return [
            'id' => $paiement->public_id,
            'reference_hot_koki' => $paiement->public_id,
            'reference_operateur' => $paiement->reference_operateur,
            'operateur' => $paiement->fournisseur,
            'statut' => $paiement->statut,
            'montant' => $paiement->montant,
            'devise' => $paiement->devise,
            'telephone_masque' => $paiement->telephone_masque,
            'code_erreur' => $paiement->code_erreur,
            'initie_le' => $paiement->initie_le,
            'confirme_le' => $paiement->confirme_le,
            'cree_le' => $paiement->created_at,
            'commande' => $commande ? [
                'id' => $commande->public_id,
                'statut' => $commande->statut,
                'total' => $commande->total,
                'frais_livraison' => $commande->frais_livraison,
            ] : null,
            'client' => $commande?->client?->user ? [
                'nom' => $commande->client->user->name,
                'email' => $commande->client->user->email,
            ] : null,
            'vendeur' => $commande?->vendeur ? [
                'id' => $commande->vendeur->public_id,
                'nom' => $commande->vendeur->nom_boutique,
            ] : null,
        ];
    }

    private function securiserCelluleCsv(mixed $value): string
    {
        $value = (string) ($value ?? '');

        return preg_match('/^[=+\-@\t\r]/u', $value) === 1 ? "'{$value}" : $value;
    }
}
