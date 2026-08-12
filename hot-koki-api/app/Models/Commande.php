<?php

// app/Models/Commande.php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Commande extends Model
{
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

    /**
     * Verifie le cycle metier actuel. L'acceptation directe d'une commande en
     * attente simule temporairement la confirmation qui viendra du paiement.
     */
    public function peutPasserAuStatut(string $nouveauStatut): bool
    {
        if (in_array($this->statut, [self::STATUT_LIVREE, self::STATUT_ANNULEE], true)) {
            return false;
        }

        if ($nouveauStatut === self::STATUT_ANNULEE) {
            return true;
        }

        $transitionSuivante = [
            self::STATUT_EN_ATTENTE_PAIEMENT => self::STATUT_RECUE,
            self::STATUT_RECUE => self::STATUT_PREPARATION,
            self::STATUT_PREPARATION => self::STATUT_EN_LIVRAISON,
            self::STATUT_EN_LIVRAISON => self::STATUT_LIVREE,
        ];

        return ($transitionSuivante[$this->statut] ?? null) === $nouveauStatut;
    }

    /**
     * Le client peut se retracter avant le debut de la preparation.
     */
    public function peutEtreAnnuleeParClient(): bool
    {
        return in_array($this->statut, [
            self::STATUT_EN_ATTENTE_PAIEMENT,
            self::STATUT_RECUE,
        ], true);
    }

    public function paiement()
    {
        // return $this->hasOne(Paiement::class);
    }
}
