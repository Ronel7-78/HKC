<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Throwable;

class HealthController extends Controller
{
    public function __invoke()
    {
        $checks = ['application' => true, 'database' => false, 'cache' => false];

        try {
            DB::select('select 1');
            $checks['database'] = true;
        } catch (Throwable) {
        }

        try {
            $key = 'health:'.bin2hex(random_bytes(8));
            Cache::put($key, true, 10);
            $checks['cache'] = Cache::get($key) === true;
            Cache::forget($key);
        } catch (Throwable) {
        }

        $healthy = ! in_array(false, $checks, true);

        return response()->json([
            'status' => $healthy ? 'ok' : 'degrade',
            'checks' => $checks,
        ], $healthy ? 200 : 503);
    }
}
