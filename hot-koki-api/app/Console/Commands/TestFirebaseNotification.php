<?php

namespace App\Console\Commands;

use App\Models\User;
use App\Services\FirebasePushService;
use Illuminate\Console\Command;

class TestFirebaseNotification extends Command
{
    protected $signature = 'firebase:test {email : Adresse email du compte destinataire}';

    protected $description = 'Envoie une notification Firebase de diagnostic à un utilisateur';

    public function handle(FirebasePushService $firebase): int
    {
        $email = mb_strtolower(trim((string) $this->argument('email')));
        $user = User::query()->where('email', $email)->first();
        if (! $user) {
            $this->error('Aucun utilisateur ne correspond à cette adresse email.');

            return self::FAILURE;
        }

        if ($user->pushTokens()->doesntExist()) {
            $this->error('Aucun appareil Firebase enregistré pour ce compte. Ouvrez la nouvelle APK et reconnectez-vous.');

            return self::FAILURE;
        }

        $firebase->envoyer(
            $user,
            'Test Hot Koki',
            'Les notifications sonores fonctionnent correctement sur cet appareil.',
            ['type' => 'test_systeme'],
        );

        $this->info('Demande Firebase envoyée sans afficher de token ni de donnée secrète.');

        return self::SUCCESS;
    }
}
