<?php

return [
    // "campay" centralise MTN et Orange chez l'agrégateur. "direct" conserve
    // les connecteurs opérateur historiques sans les activer.
    'gateway' => env('PAYMENT_GATEWAY', 'direct'),
];
