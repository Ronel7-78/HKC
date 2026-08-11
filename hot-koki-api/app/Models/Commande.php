<?php
// app/Models/Commande.php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Commande extends Model
{
    protected $fillable = [
        'client_id', 'vendeur_id', 'statut', 'adresse_livraison',
        'latitude_client', 'longitude_client', 'sous_total', 'frais_livraison', 'total',
    ];

    public function client()
    {
        return $this->belongsTo(Client::class);
    }

    public function vendeur()
    {
        return $this->belongsTo(Vendeur::class);
    }

    public function items()
    {
        return $this->hasMany(CommandeItem::class);
    }

    public function paiement()
    {
       // return $this->hasOne(Paiement::class);
    }
}