<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Jobs\VerifierPaiementFlutterwave;
use App\Models\Paiement;
use Illuminate\Http\Request;

class FlutterwaveWebhookController extends Controller
{
    public function __invoke(Request $request)
    {
        $secret = (string) config('services.flutterwave.webhook_secret');
        $signature = (string) $request->header('verif-hash');

        if ($secret === '' || $signature === '' || ! hash_equals($secret, $signature)) {
            return response()->json(['message' => 'Signature invalide.'], 401);
        }

        $reference = (string) $request->input('data.tx_ref');
        $paiement = $reference === '' ? null : Paiement::query()
            ->where('passerelle', Paiement::PASSERELLE_FLUTTERWAVE)
            ->where('reference_interne', $reference)
            ->first();

        if ($paiement) {
            VerifierPaiementFlutterwave::dispatch($paiement->id)->onQueue('paiements');
        }

        return response()->json(['message' => 'Notification reçue.']);
    }
}
