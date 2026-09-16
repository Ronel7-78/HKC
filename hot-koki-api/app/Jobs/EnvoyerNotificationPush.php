<?php

namespace App\Jobs;

use App\Models\User;
use App\Services\FirebasePushService;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

class EnvoyerNotificationPush implements ShouldQueue
{
    use Queueable;

    public int $tries = 3;

    public function __construct(
        public readonly int $userId,
        public readonly string $titre,
        public readonly string $message,
        public readonly array $meta = [],
    ) {
        $this->onQueue('default');
    }

    public function handle(FirebasePushService $firebase): void
    {
        $user = User::query()->find($this->userId);
        if ($user) {
            $firebase->envoyer($user, $this->titre, $this->message, $this->meta);
        }
    }
}
