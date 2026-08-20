<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->timestamp('conditions_acceptees_le')->nullable()->after('role');
            $table->string('conditions_version', 30)->nullable()->after('conditions_acceptees_le');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['conditions_acceptees_le', 'conditions_version']);
        });
    }
};
