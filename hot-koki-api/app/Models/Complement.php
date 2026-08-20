<?php

// app/Models/Complement.php

namespace App\Models;

use App\Models\Concerns\HasPublicId;
use Illuminate\Database\Eloquent\Model;

class Complement extends Model
{
    use HasPublicId;

    protected $fillable = ['nom'];

    public function produits()
    {
        return $this->belongsToMany(Produit::class, 'produit_complement');
    }
}
