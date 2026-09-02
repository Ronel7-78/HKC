<?php

namespace App\Providers;

use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;
use Symfony\Component\HttpFoundation\Response;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        $response = fn (Request $request, array $headers): Response => response()->json([
            'message' => 'Trop de tentatives. Réessayez dans quelques instants.',
            'code' => 'TROP_DE_REQUETES',
            'retry_after' => (int) ($headers['Retry-After'] ?? 60),
        ], 429, $headers);

        RateLimiter::for('api-global', function (Request $request) use ($response) {
            $key = $request->user()
                ? 'user:'.$request->user()->getAuthIdentifier()
                : 'ip:'.$request->ip();

            return Limit::perMinute($request->user() ? 120 : 60)
                ->by($key)
                ->response($response);
        });

        RateLimiter::for('login', fn (Request $request) => [
            Limit::perMinute(5)->by('login-minute:'.$this->emailEtIp($request))->response($response),
            Limit::perHour(20)->by('login-hour:'.$this->emailEtIp($request))->response($response),
        ]);
        RateLimiter::for('register', fn (Request $request) => Limit::perHour(3)
            ->by('register:'.$request->ip())->response($response));
        RateLimiter::for('email-send', fn (Request $request) => [
            Limit::perMinute(1)->by('email-minute:'.$this->emailEtIp($request))->response($response),
            Limit::perHour(5)->by('email-hour:'.$this->emailEtIp($request))->response($response),
        ]);
        RateLimiter::for('email-verify', fn (Request $request) => Limit::perMinute(5)
            ->by('email-verify:'.$this->emailEtIp($request))->response($response));
        RateLimiter::for('order-preview', fn (Request $request) => Limit::perMinute(30)
            ->by('order-preview:'.$this->userOuIp($request))->response($response));
        RateLimiter::for('order-create', fn (Request $request) => Limit::perMinute(10)
            ->by('order-create:'.$this->userOuIp($request))->response($response));
        RateLimiter::for('payment-create', fn (Request $request) => Limit::perMinutes(5, 3)
            ->by('payment-create:'.$this->userOuIp($request).':'.$this->routeKey($request, 'commande'))
            ->response($response));
        RateLimiter::for('payment-sync', fn (Request $request) => Limit::perMinute(6)
            ->by('payment-sync:'.$this->userOuIp($request).':'.$this->routeKey($request, 'paiement'))
            ->response($response));
        RateLimiter::for('review', fn (Request $request) => Limit::perHour(5)
            ->by('review:'.$this->userOuIp($request))->response($response));
        RateLimiter::for('admin', fn (Request $request) => Limit::perMinute(120)
            ->by('admin:'.$this->userOuIp($request))->response($response));
        RateLimiter::for('webhook', fn (Request $request) => Limit::perMinute(120)
            ->by('webhook:'.$request->ip())->response($response));
        RateLimiter::for('health', fn (Request $request) => Limit::perMinute(30)
            ->by('health:'.$request->ip())->response($response));
    }

    private function emailEtIp(Request $request): string
    {
        return hash('sha256', mb_strtolower(trim((string) $request->input('email'))).'|'.$request->ip());
    }

    private function userOuIp(Request $request): string
    {
        return $request->user()
            ? 'user:'.$request->user()->getAuthIdentifier()
            : 'ip:'.$request->ip();
    }

    private function routeKey(Request $request, string $parameter): string
    {
        $value = $request->route($parameter);

        return is_object($value) && method_exists($value, 'getRouteKey')
            ? (string) $value->getRouteKey()
            : (string) $value;
    }
}
