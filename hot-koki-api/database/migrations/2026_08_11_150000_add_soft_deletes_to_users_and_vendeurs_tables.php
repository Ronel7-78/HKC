<?php

// Cette migration permet de supprimer un vendeur sans perdre son historique.

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Ajoute la date de suppression logique aux comptes et profils vendeurs.
     */
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->softDeletes();
        });

        Schema::table('vendeurs', function (Blueprint $table) {
            $table->softDeletes();
        });
    }

    /**
     * Retire les colonnes ajoutees si la migration est annulee.
     */
    public function down(): void
    {
        Schema::table('vendeurs', function (Blueprint $table) {
            $table->dropSoftDeletes();
        });

        Schema::table('users', function (Blueprint $table) {
            $table->dropSoftDeletes();
        });
    }
};
