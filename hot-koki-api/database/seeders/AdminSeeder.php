<?php

namespace Database\Seeders;

use App\Models\Admin;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use LogicException;

class AdminSeeder extends Seeder
{
    /**
     * Cree l'administrateur utilise uniquement pour le developpement local.
     */
    public function run(): void
    {
        if (! app()->environment(['local', 'testing'])) {
            throw new LogicException('AdminSeeder est strictement réservé au développement local et aux tests.');
        }

        DB::transaction(function () {
            $user = User::firstOrNew(['email' => 'admin@hotkoki.test']);
            $user->fill([
                'name' => 'Admin Hot Koki',
                'telephone' => '600000000',
                'password' => Hash::make('password'),
            ])->forceFill([
                'role' => 'admin',
                'email_verified_at' => now(),
            ])->save();

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
