<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Avis;
use App\Models\AvisSignalement;
use App\Services\NotificationService;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class AvisSignalementController extends Controller
{
    /**
     * Signaler un avis public. Un même compte ne peut signaler un même avis
     * qu'une seule fois, ce qui évite les signalements répétés abusifs.
     */
    public function store(Request $request, Avis $avis)
    {
        if ($avis->masque_le !== null) {
            return response()->json(['message' => 'Cet avis n’est plus public.'], 404);
        }

        $avis->loadMissing('client');
        if ($avis->client?->user_id === $request->user()->id) {
            return response()->json(['message' => 'Vous ne pouvez pas signaler votre propre avis.'], 422);
        }

        $data = $request->validate([
            'motif' => ['required', Rule::in([
                'spam',
                'harcelement',
                'contenu_sexuel',
                'violence',
                'discours_haineux',
                'autre',
            ])],
            'details' => 'nullable|string|max:1000',
        ]);

        $signalement = AvisSignalement::firstOrCreate(
            [
                'avis_id' => $avis->id,
                'signale_par_user_id' => $request->user()->id,
            ],
            [
                ...$data,
                'statut' => AvisSignalement::STATUT_OUVERT,
            ],
        );

        if (! $signalement->wasRecentlyCreated) {
            return response()->json([
                'message' => 'Vous avez déjà signalé cet avis. Il sera examiné par notre équipe.',
                'signalement' => $signalement,
            ]);
        }

        NotificationService::admins(
            'avis_signale',
            'Avis signalé',
            'Un avis public a été signalé et nécessite une vérification.',
            ['avis_id' => $avis->id, 'signalement_id' => $signalement->id]
        );

        return response()->json([
            'message' => 'Merci. Votre signalement sera examiné.',
            'signalement' => $signalement,
        ], 201);
    }
}
