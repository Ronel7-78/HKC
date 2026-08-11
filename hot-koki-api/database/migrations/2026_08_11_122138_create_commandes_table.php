<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void{
        Schema::create('commandes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('client_id')->constrained('clients')->onDelete('cascade');
            $table->foreignId('vendeur_id')->constrained('vendeurs')->onDelete('cascade');
            $table->enum('statut', ['en_attente_paiement', 'recue', 'preparation', 'en_livraison', 'livree', 'annulee'])
                ->default('en_attente_paiement');
            $table->string('adresse_livraison');
            $table->decimal('latitude_client', 10, 7);
            $table->decimal('longitude_client', 10, 7);
            $table->decimal('sous_total', 8, 2);
            $table->decimal('frais_livraison', 8, 2);
            $table->decimal('total', 8, 2);
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('commandes');
    }
};
