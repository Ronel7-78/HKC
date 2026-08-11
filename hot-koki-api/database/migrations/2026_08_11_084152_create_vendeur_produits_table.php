<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('vendeur_produits', function (Blueprint $table) {
            $table->id();
            $table->foreignId('vendeur_id')->constrained()->onDelete('cascade');
            $table->foreignId('produit_id')->constrained()->onDelete('cascade');
            $table->enum('statut', ['disponible', 'rupture'])->default('rupture');
            $table->timestamps();
            $table->unique(['vendeur_id', 'produit_id']); // un vendeur ne peut avoir qu'une ligne par produit
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('vendeur_produits');
    }
};
