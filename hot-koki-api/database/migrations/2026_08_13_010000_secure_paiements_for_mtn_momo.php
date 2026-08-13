<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('paiements', function (Blueprint $table) {
            // Le chiffrement applicatif produit une valeur plus longue que le MSISDN.
            $table->text('telephone')->change();
            $table->string('telephone_masque', 20)->nullable()->after('telephone');
            $table->char('callback_hash', 64)->nullable()->unique()->after('donnees_operateur');
            $table->unsignedSmallInteger('tentatives_statut')->default(0)->after('callback_hash');
            $table->timestamp('prochaine_verification_le')->nullable()->after('tentatives_statut');
        });
    }

    public function down(): void
    {
        Schema::table('paiements', function (Blueprint $table) {
            $table->dropUnique(['callback_hash']);
            $table->dropColumn([
                'telephone_masque',
                'callback_hash',
                'tentatives_statut',
                'prochaine_verification_le',
            ]);
            $table->string('telephone', 20)->change();
        });
    }
};
