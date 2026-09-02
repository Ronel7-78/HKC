<?php

use App\Jobs\VerifierPaiementMtn;
use App\Jobs\VerifierPaiementOrange;
use App\Models\EmailAuthCode;
use App\Models\Paiement;
use App\Services\Payments\MtnMomoService;
use App\Services\Payments\OrangeMoneyService;
use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

Artisan::command('mtn:test-config', function () {
    try {
        app(MtnMomoService::class)->testerConfiguration();
        $this->info('Configuration MTN MoMo valide : jeton sandbox obtenu.');
    } catch (Throwable $exception) {
        $this->error($exception->getMessage());

        return 1;
    }

    return 0;
})->purpose('Valider la configuration MTN MoMo sans afficher les secrets');

Artisan::command('mtn:check-env', function () {
    $required = [
        'MTN_MOMO_CALLBACK_BASE_URL' => 'callback_base_url',
        'MTN_MOMO_SUBSCRIPTION_KEY' => 'subscription_key',
        'MTN_MOMO_API_USER' => 'api_user',
        'MTN_MOMO_API_KEY' => 'api_key',
    ];

    $missing = [];
    foreach ($required as $environmentName => $configName) {
        if (blank(config('services.mtn_momo.'.$configName))) {
            $missing[] = $environmentName;
        }
    }

    if ($missing !== []) {
        $this->error('Configuration MTN incomplète. Variables à renseigner dans .env :');
        foreach ($missing as $name) {
            $this->line(' - '.$name);
        }

        return 1;
    }

    $this->info('Toutes les variables MTN requises sont présentes.');
    $this->comment('Aucune valeur secrète n’a été affichée et aucun appel MTN n’a été effectué.');

    return 0;
})->purpose('Vérifier la présence des secrets MTN sans les afficher ni appeler MTN');

Artisan::command('orange:test-config', function () {
    try {
        app(OrangeMoneyService::class)->testerConfiguration();
        $this->info('Configuration Orange Money valide : jeton obtenu.');
    } catch (Throwable $exception) {
        $this->error($exception->getMessage());

        return 1;
    }

    return 0;
})->purpose('Valider la configuration Orange Money sans afficher les secrets');

Artisan::command('orange:check-env', function () {
    $required = [
        'ORANGE_MONEY_CLIENT_ID' => 'client_id',
        'ORANGE_MONEY_CLIENT_SECRET' => 'client_secret',
        'ORANGE_MONEY_MERCHANT_KEY' => 'merchant_key',
        'ORANGE_MONEY_CALLBACK_BASE_URL' => 'callback_base_url',
        'ORANGE_MONEY_RETURN_URL' => 'return_url',
        'ORANGE_MONEY_CANCEL_URL' => 'cancel_url',
    ];
    $missing = [];
    foreach ($required as $environmentName => $configName) {
        if (blank(config('services.orange_money.'.$configName))) {
            $missing[] = $environmentName;
        }
    }
    if ($missing !== []) {
        $this->error('Configuration Orange Money incomplète. Variables à renseigner :');
        foreach ($missing as $name) {
            $this->line(' - '.$name);
        }

        return 1;
    }
    $this->info('Toutes les variables Orange Money requises sont présentes.');

    return 0;
})->purpose('Vérifier la présence des secrets Orange Money sans les afficher');

Artisan::command('deploy:check', function () {
    $errors = [];
    if (Artisan::call('security:check-secrets') !== 0) {
        $errors[] = 'Le contrôle automatique des secrets a échoué.';
    }
    if (app()->environment('production') && Artisan::call('security:check-database') !== 0) {
        $errors[] = 'Le compte MySQL applicatif possède des privilèges excessifs ou invérifiables.';
    }
    $environment = app()->environment();
    if (! in_array($environment, ['staging', 'production'], true)) {
        $errors[] = 'APP_ENV doit être staging ou production.';
    }
    if (config('app.debug')) {
        $errors[] = 'APP_DEBUG doit être false.';
    }
    if (! str_starts_with((string) config('app.url'), 'https://')) {
        $errors[] = 'APP_URL doit utiliser HTTPS.';
    }
    if (! config('app.key')) {
        $errors[] = 'APP_KEY est absent.';
    }
    if (! is_int(config('sanctum.expiration'))
        || config('sanctum.expiration') < 60
        || config('sanctum.expiration') > 43200) {
        $errors[] = 'SANCTUM_EXPIRATION doit être compris entre 60 minutes et 30 jours.';
    }
    if (blank(config('sanctum.token_prefix'))) {
        $errors[] = 'SANCTUM_TOKEN_PREFIX doit être renseigné pour faciliter la détection des fuites.';
    }
    if (! is_int(config('sanctum.admin_expiration'))
        || config('sanctum.admin_expiration') < 30
        || config('sanctum.admin_expiration') > 1440) {
        $errors[] = 'ADMIN_TOKEN_EXPIRATION doit être compris entre 30 minutes et 24 heures.';
    }
    if (str_contains((string) config('app.url'), 'example.com')) {
        $errors[] = 'APP_URL contient encore le domaine d’exemple.';
    }
    if (config('database.default') === 'sqlite') {
        $errors[] = 'SQLite ne doit pas être utilisé pour cet environnement.';
    }
    $database = config('database.connections.'.config('database.default'));
    if (blank($database['username'] ?? null) || ($database['username'] ?? null) === 'root') {
        $errors[] = 'La base doit utiliser un compte applicatif dédié, jamais root.';
    }
    if (mb_strlen((string) ($database['password'] ?? '')) < 16) {
        $errors[] = 'Le mot de passe de la base doit contenir au moins 16 caractères.';
    }
    if (config('cache.default') === 'array') {
        $errors[] = 'Le cache array ne convient pas au déploiement.';
    }
    if (config('queue.default') === 'sync') {
        $errors[] = 'La queue sync ne convient pas aux paiements.';
    }
    if (config('filesystems.default') === 'local') {
        $errors[] = 'Le stockage local n’est pas persistant en environnement distribué.';
    }
    if (in_array(config('mail.default'), ['log', 'array'], true)) {
        $errors[] = 'Un transport email réel est obligatoire pour les codes de sécurité.';
    }
    if (config('mail.default') === 'smtp'
        && (blank(config('mail.mailers.smtp.username')) || blank(config('mail.mailers.smtp.password')))) {
        $errors[] = 'Les identifiants SMTP sont incomplets.';
    }
    if (config('mail.from.address') === 'hello@example.com') {
        $errors[] = 'MAIL_FROM_ADDRESS doit utiliser une adresse Hot Koki valide.';
    }
    foreach (['base_url', 'subscription_key', 'api_user', 'api_key', 'callback_base_url'] as $key) {
        if (! config('services.mtn_momo.'.$key)) {
            $errors[] = 'Configuration MTN absente : '.$key.'.';
        }
    }
    if ($environment === 'production') {
        if (config('services.mtn_momo.target_environment') === 'sandbox') {
            $errors[] = 'MTN sandbox est interdit en production.';
        }
        if (! config('services.mtn_momo.callback_allowed_ips')) {
            $errors[] = 'Les IP de callback MTN doivent être autorisées en production.';
        }
        if (config('services.orange_money.enabled')
            && config('services.orange_money.environment') === 'sandbox') {
            $errors[] = 'Orange Money sandbox est interdit en production.';
        }
    }

    if ($errors) {
        foreach ($errors as $error) {
            $this->error($error);
        }

        return 1;
    }

    $this->info('Configuration de déploiement valide pour '.$environment.'.');

    return 0;
})->purpose('Vérifier les exigences avant un déploiement staging ou production');

Schedule::call(function () {
    Paiement::query()
        ->where('fournisseur', Paiement::FOURNISSEUR_MTN_MOMO)
        ->whereIn('statut', Paiement::STATUTS_ACTIFS)
        ->where('tentatives_statut', '<', config('services.mtn_momo.poll_max_attempts'))
        ->where(function ($query) {
            $query->whereNull('prochaine_verification_le')
                ->orWhere('prochaine_verification_le', '<=', now());
        })
        ->pluck('id')
        ->each(fn (int $id) => VerifierPaiementMtn::dispatch($id)->onQueue('paiements'));
})->everyMinute()->name('mtn-momo-polling')->withoutOverlapping();

Schedule::call(function () {
    if (! config('services.orange_money.enabled')) {
        return;
    }
    Paiement::query()
        ->where('fournisseur', Paiement::FOURNISSEUR_ORANGE_MONEY)
        ->whereIn('statut', Paiement::STATUTS_ACTIFS)
        ->where('tentatives_statut', '<', config('services.orange_money.poll_max_attempts'))
        ->where(function ($query) {
            $query->whereNull('prochaine_verification_le')
                ->orWhere('prochaine_verification_le', '<=', now());
        })
        ->pluck('id')
        ->each(fn (int $id) => VerifierPaiementOrange::dispatch($id)->onQueue('paiements'));
})->everyMinute()->name('orange-money-polling')->withoutOverlapping();

Schedule::call(function () {
    EmailAuthCode::query()
        ->where('created_at', '<', now()->subDay())
        ->delete();
})->daily()->name('purge-email-auth-codes')->withoutOverlapping();

Schedule::command('sanctum:prune-expired --hours=24')
    ->daily()
    ->name('purge-sanctum-expired-tokens')
    ->withoutOverlapping();
