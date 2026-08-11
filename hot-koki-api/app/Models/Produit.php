<?php
// app/Models/Produit.php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Produit extends Model
{
    protected $fillable = ['nom', 'description', 'prix', 'photo'];

    public function complements()
    {
        return $this->belongsToMany(Complement::class, 'produit_complement');
    }

    public function vendeurs()
    {
        return $this->belongsToMany(Vendeur::class, 'vendeur_produits')
                     ->withPivot('statut')
                     ->withTimestamps();
    }
}