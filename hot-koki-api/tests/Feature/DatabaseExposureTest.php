<?php

namespace Tests\Feature;

use Tests\TestCase;

class DatabaseExposureTest extends TestCase
{
    public function test_les_fichiers_de_configuration_et_de_base_ne_sont_pas_exposes_par_http(): void
    {
        foreach ([
            '/.env',
            '/.env.production',
            '/database/database.sqlite',
            '/database/exports/hot_koki_chaud.sql',
            '/composer.json',
        ] as $path) {
            $this->get($path)->assertNotFound();
        }
    }
}
