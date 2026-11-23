<?php

use App\Jobs\VerifierPaiementCamPay;
use App\Models\Client;
use App\Models\EmailAuthCode;
use App\Models\Paiement;
use App\Models\User;
use App\Services\Payments\CamPayService;
use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

Artisan::command('k6:seed-order-clients {runId} {--count=100}', function () {
    if (! app()->environment('staging')) {
        $this->error('Cette commande est autorisée uniquement sur staging.');

        return 1;
    }

    $runId = (string) $this->argument('runId');
    $count = (int) $this->option('count');
    if (! preg_match('/^[A-Za-z0-9_-]{8,40}$/', $runId) || $count < 1 || $count > 100) {
        $this->error('runId : 8 a 40 caracteres alphanumeriques, tirets ou underscores ; count : 1 a 100.');

        return 1;
    }

    $password = $this->secret('Mot de passe commun des clients de charge (non affiche)');
    if (blank($password)) {
        $this->error('Mot de passe requis. Aucun compte cree.');

        return 1;
    }

    $emails = collect(range(1, $count))
        ->map(fn (int $index): string => "k6-{$runId}-{$index}@loadtest.hotkoki.test");
    if (User::withTrashed()->whereIn('email', $emails)->exists()) {
        $this->error('Ce runId a deja ete utilise. Choisissez-en un nouveau pour ne pas reutiliser de comptes.');

        return 1;
    }

    $tokens = [];
    foreach ($emails as $index => $email) {
        $number = $index + 1;
        $user = new User();
        $user->forceFill([
            'name' => "K6 Client {$runId} {$number}",
            'email' => $email,
            'telephone' => '699'.str_pad((string) $number, 6, '0', STR_PAD_LEFT),
            'password' => $password,
            'role' => 'client',
            'email_verified_at' => now(),
            'conditions_acceptees_le' => now(),
            'conditions_version' => config('legal.version'),
        ])->save();
        Client::create([
            'user_id' => $user->id,
            'nom' => 'K6',
            'prenom' => "Client {$number}",
            'adresse_texte' => 'Compte fictif de test de charge staging',
            'latitude' => 3.8667,
            'longitude' => 11.5167,
        ]);

        $tokens[] = [
            'index' => $number,
            'email' => $email,
            'token' => $user->issueAuthToken(),
        ];
    }

    $directory = storage_path('app/secure');
    if (! is_dir($directory)) {
        mkdir($directory, 0750, true);
    }
    $path = $directory."/k6-order-clients-{$runId}.json";
    file_put_contents($path, json_encode($tokens, JSON_THROW_ON_ERROR));
    chmod($path, 0600);

    $this->info("{$count} clients staging crees.");
    $this->comment("Fichier de jetons cree : {$path}");
    $this->comment('Ne pas afficher, versionner ou partager ce fichier. Supprimez-le apres le test.');
})->purpose('Creer des clients et jetons fictifs pour le test k6 de commandes staging');

Artisan::command('campay:check-env', function () {
    $required = [
        'CAMPAY_APP_USERNAME' => 'username',
        'CAMPAY_APP_PASSWORD' => 'password',
        'CAMPAY_BASE_URL' => 'base_url',
    ];
    $missing = [];
    foreach ($required as $environmentName => $configName) {
        if (blank(config('services.campay.'.$configName))) {
            $missing[] = $environmentName;
        }
    }
    if ($missing !== []) {
        $this->error('Configuration CamPay incomplète. Variables à renseigner :');
        foreach ($missing as $name) {
            $this->line(' - '.$name);
        }

        return 1;
    }
    $this->info('Toutes les variables CamPay requises sont présentes.');
    $this->comment('Aucune valeur secrète n’a été affichée et aucun paiement n’a été initié.');

    return 0;
})->purpose('Vérifier la présence des secrets CamPay sans les afficher');

Artisan::command('campay:test-config', function () {
    try {
        app(CamPayService::class)->testerConfiguration();
        $this->info('Configuration CamPay valide : solde applicatif accessible.');
    } catch (Throwable $exception) {
        $this->error($exception->getMessage());

        return 1;
    }

    return 0;
})->purpose('Valider les identifiants CamPay sans afficher les secrets');

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
    $paymentGateway = config('payments.gateway');
    if ($paymentGateway !== Paiement::PASSERELLE_CAMPAY) {
        $errors[] = 'PAYMENT_GATEWAY doit valoir campay.';
    }
    if (! config('services.campay.enabled')) {
        $errors[] = 'CamPay doit être activé.';
    }
    foreach (['base_url', 'username', 'password'] as $key) {
        if (! config('services.campay.'.$key)) {
            $errors[] = 'Configuration CamPay absente : '.$key.'.';
        }
    }
    if ($environment === 'production') {
        if (strtoupper((string) config('services.campay.environment')) !== 'LIVE') {
            $errors[] = 'CamPay DEV est interdit en production.';
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
    if (config('payments.gateway') !== Paiement::PASSERELLE_CAMPAY
        || ! config('services.campay.enabled')) {
        return;
    }
    Paiement::query()
        ->where('passerelle', Paiement::PASSERELLE_CAMPAY)
        ->whereIn('statut', Paiement::STATUTS_ACTIFS)
        ->where('tentatives_statut', '<', config('services.campay.poll_max_attempts'))
        ->where(function ($query) {
            $query->whereNull('prochaine_verification_le')
                ->orWhere('prochaine_verification_le', '<=', now());
        })
        ->pluck('id')
        ->each(fn (int $id) => VerifierPaiementCamPay::dispatch($id)->onQueue('paiements'));
})->everyMinute()->name('campay-polling')->withoutOverlapping();

Schedule::call(function () {
    EmailAuthCode::query()
        ->where('created_at', '<', now()->subDay())
        ->delete();
})->daily()->name('purge-email-auth-codes')->withoutOverlapping();

Schedule::command('sanctum:prune-expired --hours=24')
    ->daily()
    ->name('purge-sanctum-expired-tokens')
    ->withoutOverlapping();
