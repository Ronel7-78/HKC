<?php

// app/Models/User.php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    // SoftDeletes conserve l'historique d'un vendeur supprime par l'admin.
    use HasApiTokens, HasFactory, Notifiable, SoftDeletes;

    protected $fillable = [
        'name',
        'email',
        'telephone',
        'password',
        'role',
        'conditions_acceptees_le',
        'conditions_version',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected $casts = [
        'email_verified_at' => 'datetime',
        'password' => 'hashed',
        'conditions_acceptees_le' => 'datetime',
    ];

    protected static function booted(): void
    {
        static::updating(function (User $user): void {
            if ($user->isDirty('email')) {
                $user->email = mb_strtolower(trim($user->email));
                $user->email_verified_at = null;
                $user->tokens()->delete();
            }
        });
    }

    public function client()
    {
        return $this->hasOne(Client::class);
    }

    public function vendeur()
    {
        return $this->hasOne(Vendeur::class);
    }

    public function admin()
    {
        return $this->hasOne(Admin::class);
    }

    public function isAdmin()
    {
        return $this->role === 'admin';
    }

    public function isVendeur()
    {
        return $this->role === 'vendeur';
    }

    public function isClient()
    {
        return $this->role === 'client';
    }
}
