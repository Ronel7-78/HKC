<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('produits', function (Blueprint $table): void {
            $table->softDeletes();
        });

        Schema::table('commandes', function (Blueprint $table): void {
            $table->string('idempotency_key', 128)->nullable()->after('vendeur_id');
            $table->timestamp('masquee_client_le')->nullable()->after('statut');
            $table->unique(['client_id', 'idempotency_key'], 'commandes_client_idempotency_unique');
            $table->index('masquee_client_le');
        });

        Schema::table('paiements', function (Blueprint $table): void {
            $table->string('idempotency_key', 128)->nullable()->after('commande_id');
            $table->unique(['commande_id', 'idempotency_key'], 'paiements_commande_idempotency_unique');
        });
    }

    public function down(): void
    {
        Schema::table('paiements', function (Blueprint $table): void {
            $table->dropUnique('paiements_commande_idempotency_unique');
            $table->dropColumn('idempotency_key');
        });

        Schema::table('commandes', function (Blueprint $table): void {
            $table->dropIndex(['masquee_client_le']);
            $table->dropUnique('commandes_client_idempotency_unique');
            $table->dropColumn(['idempotency_key', 'masquee_client_le']);
        });

        Schema::table('produits', function (Blueprint $table): void {
            $table->dropSoftDeletes();
        });
    }
};
