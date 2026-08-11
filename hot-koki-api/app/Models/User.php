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
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected $casts = [
        'email_verified_at' => 'datetime',
        'password' => 'hashed',
    ];

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
