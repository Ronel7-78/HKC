<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('avis', function (Blueprint $table) {
            $table->timestamp('masque_le')->nullable()->index()->after('commentaire');
            $table->foreignId('masque_par_user_id')
                ->nullable()
                ->after('masque_le')
                ->constrained('users')
                ->nullOnDelete();
            $table->string('motif_masquage', 255)->nullable()->after('masque_par_user_id');
        });

        Schema::create('avis_signalements', function (Blueprint $table) {
            $table->id();
            $table->foreignId('avis_id')->constrained('avis')->cascadeOnDelete();
            $table->foreignId('signale_par_user_id')->constrained('users')->cascadeOnDelete();
            $table->string('motif', 40);
            $table->text('details')->nullable();
            $table->string('statut', 20)->default('ouvert')->index();
            $table->foreignId('traite_par_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('traite_le')->nullable();
            $table->string('decision', 20)->nullable();
            $table->text('note_moderation')->nullable();
            $table->timestamps();

            $table->unique(['avis_id', 'signale_par_user_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('avis_signalements');

        Schema::table('avis', function (Blueprint $table) {
            $table->dropConstrainedForeignId('masque_par_user_id');
            $table->dropColumn(['masque_le', 'motif_masquage']);
        });
    }
};
