<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::table('commandes')
            ->whereIn('statut', ['preparation', 'en_livraison'])
            ->update(['statut' => 'recue']);
    }

    public function down(): void
    {
        // Les deux anciens états ne peuvent pas être reconstruits sans ambiguïté.
    }
};
