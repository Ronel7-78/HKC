<?php

namespace App\Console\Commands;

use App\Models\Admin;
use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

class CreateProductionAdmin extends Command
{
    protected $signature = 'admin:create';

    protected $description = 'Crée le premier administrateur de production de façon interactive et sécurisée';

    public function handle(): int
    {
        if (! app()->environment('production')) {
            $this->error('Cette commande est autorisée uniquement en production.');

            return self::FAILURE;
        }

        $nom = trim((string) $this->ask('Nom'));
        $prenom = trim((string) $this->ask('Prénom'));
        $email = mb_strtolower(trim((string) $this->ask('Adresse e-mail')));
        $telephone = trim((string) $this->ask('Téléphone (+237...)'));
        $password = (string) $this->secret('Mot de passe (non affiché)');
        $confirmation = (string) $this->secret('Confirmation du mot de passe');

        if ($nom === '' || $prenom === '' || ! filter_var($email, FILTER_VALIDATE_EMAIL)
            || mb_strlen($telephone) < 8 || mb_strlen($telephone) > 255) {
            $this->error('Nom, prénom, e-mail valide et téléphone valide sont requis. Aucun compte créé.');

            return self::FAILURE;
        }

        if (mb_strlen($password) < 12 || ! hash_equals($password, $confirmation)) {
            $this->error('Le mot de passe doit contenir au moins 12 caractères et correspondre à sa confirmation.');

            return self::FAILURE;
        }

        if (User::withTrashed()->where('email', $email)->exists()
            || User::withTrashed()->where('telephone', $telephone)->exists()) {
            $this->error('Un compte actif ou archivé utilise déjà cet e-mail ou ce téléphone.');

            return self::FAILURE;
        }

        DB::transaction(function () use ($nom, $prenom, $email, $telephone, $password): void {
            $user = User::create([
                'name' => trim("{$prenom} {$nom}"),
                'email' => $email,
                'telephone' => $telephone,
                'password' => Hash::make($password),
                'role' => 'admin',
                'email_verified_at' => now(),
                'conditions_acceptees_le' => now(),
                'conditions_version' => config('legal.version'),
            ]);

            Admin::create([
                'user_id' => $user->id,
                'nom' => $nom,
                'prenom' => $prenom,
            ]);
        });

        $this->info('Administrateur de production créé. Connectez-vous avec son e-mail ; le mot de passe n’a pas été affiché ni enregistré dans l’historique.');

        return self::SUCCESS;
    }
}
