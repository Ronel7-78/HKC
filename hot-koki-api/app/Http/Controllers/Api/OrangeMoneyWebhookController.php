<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Jobs\VerifierPaiementOrange;
use App\Models\Paiement;
use Illuminate\Http\Request;

class OrangeMoneyWebhookController extends Controller
{
    public function __invoke(Request $request)
    {
        $token = (string) $request->input('notif_token');
        $paiement = $token === '' ? null : Paiement::query()
            ->where('fournisseur', Paiement::FOURNISSEUR_ORANGE_MONEY)
            ->where('callback_hash', hash('sha256', $token))
            ->first();

        if ($paiement) {
            VerifierPaiementOrange::dispatch($paiement->id)->onQueue('paiements');
        }

        return response()->json(['message' => 'Notification reçue.']);
    }
}
