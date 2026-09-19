<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class PaiementEvenement extends Model
{
    protected $fillable = [
        'paiement_id',
        'ancien_statut',
        'nouveau_statut',
        'source',
        'code',
        'message',
    ];

    public function paiement()
    {
        return $this->belongsTo(Paiement::class);
    }
}
