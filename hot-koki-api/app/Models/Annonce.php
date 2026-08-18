<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Annonce extends Model
{
    protected $fillable = [
        'type', 'etiquette', 'titre', 'description', 'image', 'produit_id', 'active', 'ordre',
    ];

    protected $casts = ['active' => 'boolean'];

    public function produit()
    {
        return $this->belongsTo(Produit::class);
    }
}
