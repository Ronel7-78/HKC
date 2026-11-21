<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Avis;
use App\Models\AvisSignalement;
use App\Models\Vendeur;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class AvisModerationController extends Controller
{
    public function index(Request $request)
    {
        $statut = $request->query('statut', AvisSignalement::STATUT_OUVERT);
        abort_unless(in_array($statut, [AvisSignalement::STATUT_OUVERT, AvisSignalement::STATUT_TRAITE], true), 422);

        return response()->json(
            AvisSignalement::query()
                ->where('statut', $statut)
                ->with([
                    'avis.client.user:id,name,email',
                    'avis.vendeur:id,nom_boutique',
                    'signalePar:id,name,email',
                    'traitePar:id,name,email',
                ])
                ->latest()
                ->paginate(min(max((int) $request->query('par_page', 20), 1), 50))
        );
    }

    /** Masque ou restaure sans effacer l'historique et clôt les signalements associés. */
    public function moderer(Request $request, Avis $avis)
    {
        $data = $request->validate([
            'action' => ['required', Rule::in(['masquer', 'restaurer'])],
            'note_moderation' => 'nullable|string|max:1000',
        ]);

        if ($data['action'] === 'masquer' && blank($data['note_moderation'] ?? null)) {
            return response()->json([
                'message' => 'Indiquez le motif de la modération avant de masquer un avis.',
            ], 422);
        }

        DB::transaction(function () use ($avis, $request, $data) {
            $estMasque = $data['action'] === 'masquer';
            $avis->update([
                'masque_le' => $estMasque ? now() : null,
                'masque_par_user_id' => $estMasque ? $request->user()->id : null,
                'motif_masquage' => $estMasque ? $data['note_moderation'] : null,
            ]);

            AvisSignalement::where('avis_id', $avis->id)
                ->where('statut', AvisSignalement::STATUT_OUVERT)
                ->update([
                    'statut' => AvisSignalement::STATUT_TRAITE,
                    'traite_par_user_id' => $request->user()->id,
                    'traite_le' => now(),
                    'decision' => $data['action'],
                    'note_moderation' => $data['note_moderation'] ?? null,
                    'updated_at' => now(),
                ]);

            Vendeur::whereKey($avis->vendeur_id)->update([
                'note_moyenne' => round((float) Avis::publics()->where('vendeur_id', $avis->vendeur_id)->avg('note'), 2),
            ]);
        });

        return response()->json([
            'message' => $data['action'] === 'masquer'
                ? 'Avis masqué et signalements traités.'
                : 'Avis restauré.',
            'avis' => $avis->fresh(),
        ]);
    }
}
