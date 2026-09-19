<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('paiement_evenements', function (Blueprint $table) {
            $table->id();
            $table->foreignId('paiement_id')->constrained('paiements')->cascadeOnDelete();
            $table->string('ancien_statut', 30)->nullable();
            $table->string('nouveau_statut', 30);
            $table->string('source', 30)->default('systeme');
            $table->string('code', 100)->nullable();
            $table->text('message')->nullable();
            $table->timestamps();

            $table->index(['paiement_id', 'created_at']);
            $table->index(['nouveau_statut', 'created_at']);
        });

        // Les paiements déjà présents restent visibles dans la chronologie après déploiement.
        DB::table('paiements')
            ->select(['id', 'statut', 'code_erreur', 'message_erreur', 'created_at', 'updated_at'])
            ->orderBy('id')
            ->chunkById(500, function ($paiements): void {
                DB::table('paiement_evenements')->insert(
                    $paiements->map(fn ($paiement) => [
                        'paiement_id' => $paiement->id,
                        'ancien_statut' => null,
                        'nouveau_statut' => $paiement->statut ?: 'initie',
                        'source' => 'migration',
                        'code' => $paiement->code_erreur,
                        'message' => $paiement->message_erreur ?: 'État connu lors de l’activation de l’historique.',
                        'created_at' => $paiement->created_at,
                        'updated_at' => $paiement->updated_at,
                    ])->all()
                );
            });
    }

    public function down(): void
    {
        Schema::dropIfExists('paiement_evenements');
    }
};
