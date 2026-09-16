<?php

namespace App\Services;

use App\Jobs\EnvoyerNotificationPush;
use App\Models\User;
use App\Notifications\NotificationMetier;

class NotificationService
{
    public static function envoyer(?User $user, string $type, string $titre, string $message, array $meta = []): void
    {
        if (! $user) {
            return;
        }

        $user->notify(new NotificationMetier([
            'type' => $type,
            'titre' => $titre,
            'message' => $message,
            ...$meta,
        ]));

        if (config('services.firebase.enabled')) {
            EnvoyerNotificationPush::dispatch($user->id, $titre, $message, [
                'type' => $type,
                ...$meta,
            ]);
        }
    }

    public static function admins(string $type, string $titre, string $message, array $meta = []): void
    {
        User::where('role', 'admin')->each(
            fn (User $admin) => self::envoyer($admin, $type, $titre, $message, $meta)
        );
    }
}
