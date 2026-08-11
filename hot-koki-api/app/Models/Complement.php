<?php
// app/Models/Complement.php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Complement extends Model
{
    protected $fillable = ['nom'];

    public function produits()
    {
        return $this->belongsToMany(Produit::class, 'produit_complement');
    }
}