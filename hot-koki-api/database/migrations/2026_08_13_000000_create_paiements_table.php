<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('paiements', function (Blueprint $table) {
            $table->id();
            $table->foreignId('commande_id')->constrained('commandes')->cascadeOnDelete();
            $table->uuid('reference_interne')->unique();
            $table->string('reference_operateur')->nullable()->unique();
            $table->string('fournisseur', 30);
            $table->string('telephone', 20);
            $table->decimal('montant', 10, 2);
            $table->char('devise', 3)->default('XAF');
            $table->string('statut', 30)->default('initie');
            $table->string('code_erreur')->nullable();
            $table->text('message_erreur')->nullable();
            $table->json('donnees_operateur')->nullable();
            $table->timestamp('initie_le')->nullable();
            $table->timestamp('confirme_le')->nullable();
            $table->timestamps();

            $table->index(['commande_id', 'statut']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('paiements');
    }
};
