<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Builder;

class Avis extends Model
{
    protected $table = 'avis';

    protected $fillable = [
        'commande_id',
        'client_id',
        'vendeur_id',
        'note',
        'commentaire',
        'masque_le',
        'masque_par_user_id',
        'motif_masquage',
    ];

    protected $casts = [
        'masque_le' => 'datetime',
    ];

    /** Les avis masqués restent conservés pour la traçabilité, mais ne sont plus publics. */
    public function scopePublics(Builder $query): Builder
    {
        return $query->whereNull('masque_le');
    }

    public function commande()
    {
        return $this->belongsTo(Commande::class);
    }

    public function client()
    {
        return $this->belongsTo(Client::class);
    }

    public function vendeur()
    {
        return $this->belongsTo(Vendeur::class);
    }

    public function signalements()
    {
        return $this->hasMany(AvisSignalement::class);
    }

    public function masquePar()
    {
        return $this->belongsTo(User::class, 'masque_par_user_id');
    }
}
