<?php

namespace Database\Seeders;

use App\Models\Admin;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

class AdminSeeder extends Seeder
{
    /**
     * Cree l'administrateur utilise uniquement pour le developpement local.
     */
    public function run(): void
    {
        DB::transaction(function () {
            $user = User::updateOrCreate(
                ['email' => 'admin@hotkoki.test'],
                [
                    'name' => 'Admin Hot Koki',
                    'telephone' => '600000000',
                    'password' => Hash::make('password'),
                    'role' => 'admin',
                ],
            );

            Admin::updateOrCreate(
                ['user_id' => $user->id],
                [
                    'nom' => 'Admin',
                    'prenom' => 'Hot Koki',
                ],
            );
        });
    }
}
