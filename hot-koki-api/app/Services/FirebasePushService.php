<?php

namespace App\Services;

use App\Models\PushToken;
use App\Models\User;
use Google\Auth\Credentials\ServiceAccountCredentials;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use RuntimeException;

class FirebasePushService
{
    public function envoyer(User $user, string $titre, string $message, array $meta = []): void
    {
        if (! config('services.firebase.enabled')) {
            return;
        }

        $jetonAcces = $this->jetonAcces();
        $projet = config('services.firebase.project_id');

        $user->pushTokens()->each(function (PushToken $appareil) use ($jetonAcces, $projet, $titre, $message, $meta): void {
            $response = Http::withToken($jetonAcces)
                ->acceptJson()
                ->timeout(10)
                ->post("https://fcm.googleapis.com/v1/projects/{$projet}/messages:send", [
                    'message' => [
                        'token' => $appareil->token,
                        'notification' => ['title' => $titre, 'body' => $message],
                        'data' => collect($meta)->mapWithKeys(
                            fn (mixed $value, string $key): array => [$key => is_scalar($value) ? (string) $value : json_encode($value)],
                        )->all(),
                        'android' => [
                            'priority' => 'high',
                            'notification' => ['channel_id' => 'hot_koki_updates_v1', 'sound' => 'default'],
                        ],
                        'apns' => [
                            'payload' => ['aps' => ['sound' => 'default', 'content-available' => 1]],
                        ],
                    ],
                ]);

            if ($this->jetonInvalide($response->json())) {
                $appareil->delete();
            } elseif ($response->failed()) {
                Log::warning('Envoi Firebase refusé', [
                    'user_id' => $appareil->user_id,
                    'http_status' => $response->status(),
                ]);
            }
        });
    }

    private function jetonAcces(): string
    {
        return Cache::remember('firebase.messaging.access_token', now()->addMinutes(50), function (): string {
            $chemin = (string) config('services.firebase.credentials');
            if ($chemin === '' || ! is_readable($chemin)) {
                throw new RuntimeException('Le fichier d’identifiants Firebase est absent ou illisible.');
            }

            $credentials = new ServiceAccountCredentials(
                ['https://www.googleapis.com/auth/firebase.messaging'],
                $chemin,
            );
            $token = $credentials->fetchAuthToken()['access_token'] ?? null;

            return is_string($token) && $token !== ''
                ? $token
                : throw new RuntimeException('Firebase n’a pas fourni de jeton d’accès.');
        });
    }

    private function jetonInvalide(mixed $contenu): bool
    {
        if (! is_array($contenu)) {
            return false;
        }

        return collect(data_get($contenu, 'error.details', []))
            ->contains(fn (mixed $detail): bool => is_array($detail)
                && in_array($detail['errorCode'] ?? null, ['UNREGISTERED', 'INVALID_ARGUMENT'], true));
    }
}
