<?php

// app/Models/CommandeItem.php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class CommandeItem extends Model
{
    protected $fillable = ['commande_id', 'produit_id', 'quantite', 'prix_unitaire'];

    public function commande()
    {
        return $this->belongsTo(Commande::class);
    }

    public function produit()
    {
        return $this->belongsTo(Produit::class)->withTrashed();
    }

    public function complements()
    {
        return $this->belongsToMany(Complement::class, 'commande_item_complements');
    }
}
