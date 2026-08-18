<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('annonces', function (Blueprint $table) {
            $table->id();
            $table->string('type', 30)->default('promotion');
            $table->string('etiquette')->nullable();
            $table->string('titre');
            $table->text('description')->nullable();
            $table->string('image')->nullable();
            $table->foreignId('produit_id')->nullable()->constrained('produits')->nullOnDelete();
            $table->boolean('active')->default(true);
            $table->unsignedInteger('ordre')->default(0);
            $table->timestamps();
        });

        DB::table('annonces')->insert([
            'type' => 'produit',
            'etiquette' => 'Nouveauté',
            'titre' => 'Eru de retour',
            'description' => 'Préparé ce matin — quantité limitée.',
            'produit_id' => DB::table('produits')->where('nom', 'like', '%Eru%')->value('id'),
            'active' => true,
            'ordre' => 0,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    public function down(): void
    {
        Schema::dropIfExists('annonces');
    }
};
