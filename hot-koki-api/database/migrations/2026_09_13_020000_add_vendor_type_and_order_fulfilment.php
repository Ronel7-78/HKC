<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('vendeurs', function (Blueprint $table) {
            $table->string('type_vendeur', 20)->default('ambulant')->after('nom_boutique');
            $table->boolean('accepte_express')->default(false)->after('type_vendeur');
            $table->index(['type_vendeur', 'accepte_express']);
        });

        Schema::table('commandes', function (Blueprint $table) {
            $table->string('mode_remise', 20)->default('livraison')->after('livraison_express');
        });
    }

    public function down(): void
    {
        Schema::table('commandes', fn (Blueprint $table) => $table->dropColumn('mode_remise'));
        Schema::table('vendeurs', function (Blueprint $table) {
            $table->dropIndex(['type_vendeur', 'accepte_express']);
            $table->dropColumn(['type_vendeur', 'accepte_express']);
        });
    }
};
