<?php

use App\Jobs\VerifierPaiementMtn;
use App\Models\Paiement;
use App\Services\Payments\MtnMomoService;
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

Schedule::call(function () {
    Paiement::query()
        ->whereIn('statut', Paiement::STATUTS_ACTIFS)
        ->where('tentatives_statut', '<', config('services.mtn_momo.poll_max_attempts'))
        ->where(function ($query) {
            $query->whereNull('prochaine_verification_le')
                ->orWhere('prochaine_verification_le', '<=', now());
        })
        ->pluck('id')
        ->each(fn (int $id) => VerifierPaiementMtn::dispatch($id)->onQueue('paiements'));
})->everyMinute()->name('mtn-momo-polling')->withoutOverlapping();
