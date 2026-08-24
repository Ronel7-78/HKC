<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::table('annonces')
            ->where('titre', 'Eru de retour')
            ->where('description', 'Préparé ce matin — quantité limitée.')
            ->delete();
    }

    public function down(): void
    {
        // Une donnée de démonstration supprimée ne doit pas être recréée.
    }
};
