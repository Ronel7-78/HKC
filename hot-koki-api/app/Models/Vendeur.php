<?php
// app/Models/Vendeur.php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Vendeur extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id', 'nom_boutique', 'description', 'adresse_texte',
        'latitude', 'longitude', 'statut_dispo', 'statut_compte', 'note_moyenne',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    // Relation avec les produits (via la table pivot vendeur_produits)
    public function produits()
    {
        return $this->belongsToMany(Produit::class, 'vendeur_produits')
                     ->withPivot('statut')
                     ->withTimestamps();
    }
}