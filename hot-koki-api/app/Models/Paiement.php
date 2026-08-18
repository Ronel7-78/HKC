<?php

namespace App\Models;

use App\Services\NotificationService;
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
        'telephone', 'telephone_masque', 'montant', 'devise', 'statut', 'code_erreur',
        'message_erreur', 'donnees_operateur', 'initie_le', 'confirme_le',
        'callback_hash', 'tentatives_statut', 'prochaine_verification_le',
    ];

    protected $casts = [
        'montant' => 'decimal:2',
        'telephone' => 'encrypted',
        'donnees_operateur' => 'array',
        'initie_le' => 'datetime',
        'confirme_le' => 'datetime',
        'prochaine_verification_le' => 'datetime',
    ];

    protected $hidden = ['telephone', 'callback_hash', 'donnees_operateur'];

    protected $appends = ['mode_test'];

    public function getModeTestAttribute(): bool
    {
        return config('services.mtn_momo.target_environment') === 'sandbox';
    }

    protected static function booted(): void
    {
        static::creating(function (Paiement $paiement) {
            $paiement->reference_interne ??= (string) Str::uuid();
            $paiement->telephone_masque ??= substr($paiement->telephone, 0, 5).'****'.substr($paiement->telephone, -3);
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
        $confirme = false;
        DB::transaction(function () use ($referenceOperateur, $donnees, &$confirme) {
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
                'prochaine_verification_le' => null,
            ]);

            $commande->update(['statut' => Commande::STATUT_RECUE]);
            $confirme = true;
        });

        if ($confirme) {
            $commande = $this->commande()->with('client.user', 'vendeur.user')->firstOrFail();
            NotificationService::envoyer(
                $commande->client->user,
                'paiement_reussi',
                'Paiement confirmé',
                "Le paiement de la commande #{$commande->id} a été confirmé.",
                ['commande_id' => $commande->id, 'paiement_id' => $this->id]
            );
            NotificationService::envoyer(
                $commande->vendeur->user,
                'nouvelle_commande',
                'Nouvelle commande reçue',
                "La commande payée #{$commande->id} peut être préparée.",
                ['commande_id' => $commande->id]
            );
        }
    }

    public function terminer(string $statut, ?string $code = null, ?string $message = null, array $donnees = []): void
    {
        if (! in_array($statut, [self::STATUT_ECHOUE, self::STATUT_EXPIRE, self::STATUT_ANNULE], true)) {
            throw new \InvalidArgumentException('Statut terminal de paiement invalide.');
        }

        $this->update([
            'statut' => $statut,
            'code_erreur' => $code,
            'message_erreur' => $message,
            'donnees_operateur' => $donnees ?: $this->donnees_operateur,
            'confirme_le' => now(),
            'prochaine_verification_le' => null,
        ]);

        $commande = $this->commande()->with('client.user')->firstOrFail();
        NotificationService::envoyer(
            $commande->client->user,
            'paiement_echoue',
            'Paiement non abouti',
            $message ?: "Le paiement de la commande #{$commande->id} n’a pas abouti.",
            ['commande_id' => $commande->id, 'paiement_id' => $this->id, 'statut' => $statut]
        );
    }
}
