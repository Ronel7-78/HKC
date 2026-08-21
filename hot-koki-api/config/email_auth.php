<?php

return [
    /*
    |--------------------------------------------------------------------------
    | Vérification temporaire des adresses email
    |--------------------------------------------------------------------------
    |
    | Désactivable tant que le transport SMTP n'est pas disponible. Remettre
    | EMAIL_VERIFICATION_ENABLED=true dès que les identifiants SMTP sont prêts.
    |
    */
    'verification_enabled' => env('EMAIL_VERIFICATION_ENABLED', true),
];
