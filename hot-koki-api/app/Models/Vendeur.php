<?php

// app/Models/Vendeur.php

namespace App\Models;

use App\Models\Concerns\HasPublicId;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Vendeur extends Model
{
    public const TYPE_AMBULANT = 'ambulant';

    public const TYPE_POINT_FIXE = 'point_fixe';

    // SoftDeletes masque le vendeur sans detruire son historique.
    use HasFactory, HasPublicId, SoftDeletes;

    protected $fillable = [
        'user_id', 'nom_boutique', 'description', 'adresse_texte',
        'latitude', 'longitude', 'statut_dispo', 'statut_compte', 'note_moyenne',
        'type_vendeur', 'accepte_express', 'live_latitude', 'live_longitude',
        'location_updated_at',
    ];

    protected $casts = [
        'accepte_express' => 'boolean',
        'location_updated_at' => 'datetime',
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

    public function commandes()
    {
        return $this->hasMany(Commande::class);
    }
}
