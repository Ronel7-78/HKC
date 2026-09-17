<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('vendeurs', function (Blueprint $table) {
            $table->decimal('live_latitude', 10, 7)->nullable()->after('longitude');
            $table->decimal('live_longitude', 10, 7)->nullable()->after('live_latitude');
            $table->timestamp('location_updated_at')->nullable()->after('live_longitude');
        });
    }

    public function down(): void
    {
        Schema::table('vendeurs', function (Blueprint $table) {
            $table->dropColumn(['live_latitude', 'live_longitude', 'location_updated_at']);
        });
    }
};
