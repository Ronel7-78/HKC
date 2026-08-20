<?php

// app/Models/Produit.php

namespace App\Models;

use App\Models\Concerns\HasPublicId;
use Illuminate\Database\Eloquent\Model;

class Produit extends Model
{
    use HasPublicId;

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
