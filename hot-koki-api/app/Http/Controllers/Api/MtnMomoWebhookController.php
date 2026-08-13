<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Jobs\VerifierPaiementMtn;
use App\Models\Paiement;
use Illuminate\Http\Request;

class MtnMomoWebhookController extends Controller
{
    public function __invoke(Request $request, string $transactionHash)
    {
        $ipsAutorisees = config('services.mtn_momo.callback_allowed_ips', []);

        if (config('services.mtn_momo.target_environment') !== 'sandbox' && ! $ipsAutorisees) {
            return response()->json(['message' => 'Liste des sources MTN non configurée.'], 503);
        }

        if ($ipsAutorisees && ! in_array($request->ip(), $ipsAutorisees, true)) {
            return response()->json(['message' => 'Source non autorisée.'], 403);
        }

        $paiement = Paiement::where('callback_hash', hash('sha256', $transactionHash))->first();

        if (! $paiement) {
            // Ne revele pas si une reference de transaction existe.
            return response()->json(['message' => 'Notification reçue.']);
        }

        VerifierPaiementMtn::dispatch($paiement->id)->onQueue('paiements');

        return response()->json(['message' => 'Notification reçue.']);
    }
}
