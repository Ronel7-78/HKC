<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Mailgun, Postmark, AWS and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

    'campay' => [
        'enabled' => env('CAMPAY_ENABLED', false),
        'environment' => env('CAMPAY_ENVIRONMENT', 'DEV'),
        'base_url' => env('CAMPAY_BASE_URL', 'https://demo.campay.net'),
        'username' => env('CAMPAY_APP_USERNAME'),
        'password' => env('CAMPAY_APP_PASSWORD'),
        'currency' => env('CAMPAY_CURRENCY', 'XAF'),
        'demo_amount' => (int) env('CAMPAY_DEMO_AMOUNT', 10),
        'poll_max_attempts' => (int) env('CAMPAY_POLL_MAX_ATTEMPTS', 12),
        // Taux décimaux utilisés pour calculer le prix client qui protège le
        // montant commercial après encaissement puis retrait CamPay.
        'collection_rate' => (float) env('CAMPAY_COLLECTION_RATE', 0.02),
        'withdrawal_rate' => (float) env('CAMPAY_WITHDRAWAL_RATE', 0.01),
    ],

    // Uniquement pour les tests de charge sur staging. Cette adresse ne
    // contourne jamais les limites en production.
    'k6' => [
        'test_ip' => env('K6_TEST_IP'),
    ],

    'firebase' => [
        'enabled' => env('FIREBASE_ENABLED', false),
        'project_id' => env('FIREBASE_PROJECT_ID'),
        'credentials' => env('FIREBASE_CREDENTIALS'),
    ],

];
