<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class Paiement extends Model
{
    public const FOURNISSEUR_MTN_MOMO = 'mtn_momo';

    public const STATUT_INITIE = 'initie';

    public const STATUT_EN_ATTENTE = 'en_attente';

    public const STATUT_REUSSI = 'reussi';

    public const STATUT_ECHOUE = 'echoue';

    public const STATUT_EXPIRE = 'expire';

    public const STATUT_ANNULE = 'annule';

    public const STATUTS_ACTIFS = [self::STATUT_INITIE, self::STATUT_EN_ATTENTE];

    protected $fillable = [
        'commande_id', 'reference_interne', 'reference_operateur', 'fournisseur',
        'telephone', 'montant', 'devise', 'statut', 'code_erreur',
        'message_erreur', 'donnees_operateur', 'initie_le', 'confirme_le',
    ];

    protected $casts = [
        'montant' => 'decimal:2',
        'donnees_operateur' => 'array',
        'initie_le' => 'datetime',
        'confirme_le' => 'datetime',
    ];

    protected static function booted(): void
    {
        static::creating(function (Paiement $paiement) {
            $paiement->reference_interne ??= (string) Str::uuid();
        });
    }

    public function commande()
    {
        return $this->belongsTo(Commande::class);
    }

    /**
     * Cette methode sera appelee uniquement apres verification aupres de
     * l'operateur (callback ou interrogation de statut), jamais par Flutter.
     */
    public function confirmerReussite(?string $referenceOperateur = null, array $donnees = []): void
    {
        DB::transaction(function () use ($referenceOperateur, $donnees) {
            $paiement = self::whereKey($this->id)->lockForUpdate()->firstOrFail();
            $commande = Commande::whereKey($paiement->commande_id)->lockForUpdate()->firstOrFail();

            if ($paiement->statut === self::STATUT_REUSSI) {
                return;
            }

            if (! in_array($paiement->statut, self::STATUTS_ACTIFS, true)) {
                throw new \LogicException('Un paiement terminé ne peut plus être confirmé.');
            }

            if ($commande->statut !== Commande::STATUT_EN_ATTENTE_PAIEMENT) {
                throw new \LogicException('La commande n’est plus en attente de paiement.');
            }

            $paiement->update([
                'statut' => self::STATUT_REUSSI,
                'reference_operateur' => $referenceOperateur ?? $paiement->reference_operateur,
                'donnees_operateur' => $donnees ?: $paiement->donnees_operateur,
                'confirme_le' => now(),
            ]);

            $commande->update(['statut' => Commande::STATUT_RECUE]);
        });
    }
}
