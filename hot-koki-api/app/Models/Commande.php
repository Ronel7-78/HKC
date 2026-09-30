<?php

// app/Models/Commande.php

namespace App\Models;

use App\Models\Concerns\HasPublicId;
use Illuminate\Database\Eloquent\Model;

class Commande extends Model
{
    use HasPublicId;

    public const STATUT_EN_ATTENTE_PAIEMENT = 'en_attente_paiement';

    public const STATUT_RECUE = 'recue';

    public const STATUT_PREPARATION = 'preparation';

    public const STATUT_EN_LIVRAISON = 'en_livraison';

    public const STATUT_LIVREE = 'livree';

    public const STATUT_ANNULEE = 'annulee';

    public const STATUTS = [
        self::STATUT_EN_ATTENTE_PAIEMENT,
        self::STATUT_RECUE,
        self::STATUT_PREPARATION,
        self::STATUT_EN_LIVRAISON,
        self::STATUT_LIVREE,
        self::STATUT_ANNULEE,
    ];

    protected $fillable = [
        'client_id', 'vendeur_id', 'statut', 'adresse_livraison',
        'latitude_client', 'longitude_client', 'distance_km', 'livraison_express', 'mode_remise',
        'sous_total', 'frais_livraison', 'total',
    ];

    protected $casts = [
        'distance_km' => 'decimal:3',
        'livraison_express' => 'boolean',
        'sous_total' => 'decimal:2',
        'frais_livraison' => 'decimal:2',
        'total' => 'decimal:2',
    ];

    protected $appends = ['code_commande'];

    public function getCodeCommandeAttribute(): string
    {
        $annee = ($this->created_at ?? now())->format('y');

        return 'COM-HKC-'.str_pad((string) $this->getKey(), 6, '0', STR_PAD_LEFT).'-'.$annee;
    }

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

    /** Vérifie les transitions métier proposées au vendeur. */
    public function peutPasserAuStatut(string $nouveauStatut): bool
    {
        if (in_array($this->statut, [self::STATUT_LIVREE, self::STATUT_ANNULEE], true)) {
            return false;
        }

        return $this->statut === self::STATUT_RECUE
            && $nouveauStatut === self::STATUT_LIVREE;
    }

    public function paiements()
    {
        return $this->hasMany(Paiement::class);
    }

    public function avis()
    {
        return $this->hasOne(Avis::class);
    }
}
