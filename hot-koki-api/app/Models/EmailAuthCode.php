<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class EmailAuthCode extends Model
{
    public const PURPOSE_VERIFY_EMAIL = 'verify_email';

    public const PURPOSE_RESET_PASSWORD = 'reset_password';

    protected $fillable = [
        'user_id',
        'purpose',
        'code_hash',
        'attempts',
        'expires_at',
        'used_at',
    ];

    protected $hidden = ['code_hash'];

    protected $casts = [
        'expires_at' => 'datetime',
        'used_at' => 'datetime',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
