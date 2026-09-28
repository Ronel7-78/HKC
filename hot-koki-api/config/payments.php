<?php

return [
    // "flutterwave" centralise MTN et Orange chez l'agrégateur. "direct"
    // conserve les connecteurs opérateur historiques sans les supprimer.
    'gateway' => env('PAYMENT_GATEWAY', 'direct'),
];
