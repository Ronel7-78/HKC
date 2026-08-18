<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Avis extends Model
{
    protected $table = 'avis';

    protected $fillable = ['commande_id', 'client_id', 'vendeur_id', 'note', 'commentaire'];

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
}
