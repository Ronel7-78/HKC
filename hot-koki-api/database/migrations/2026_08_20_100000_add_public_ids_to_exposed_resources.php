<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

return new class extends Migration
{
    private const TABLES = [
        'commandes',
        'paiements',
        'vendeurs',
        'produits',
        'annonces',
        'complements',
    ];

    public function up(): void
    {
        foreach (self::TABLES as $table) {
            Schema::table($table, function (Blueprint $blueprint): void {
                $blueprint->uuid('public_id')->nullable()->unique();
            });

            DB::table($table)
                ->whereNull('public_id')
                ->orderBy('id')
                ->eachById(function (object $record) use ($table): void {
                    DB::table($table)->where('id', $record->id)->update([
                        'public_id' => (string) Str::uuid(),
                    ]);
                });
        }
    }

    public function down(): void
    {
        foreach (array_reverse(self::TABLES) as $table) {
            Schema::table($table, function (Blueprint $blueprint): void {
                $blueprint->dropUnique([$blueprint->getTable().'_public_id_unique']);
                $blueprint->dropColumn('public_id');
            });
        }
    }
};
