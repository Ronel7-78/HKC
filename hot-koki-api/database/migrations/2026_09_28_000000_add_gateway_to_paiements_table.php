<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('paiements', function (Blueprint $table) {
            $table->string('passerelle', 30)->default('direct')->after('fournisseur');
            $table->index(['passerelle', 'statut']);
        });
    }

    public function down(): void
    {
        Schema::table('paiements', function (Blueprint $table) {
            $table->dropIndex(['passerelle', 'statut']);
            $table->dropColumn('passerelle');
        });
    }
};
