<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class AvisSignalement extends Model
{
    public const STATUT_OUVERT = 'ouvert';
    public const STATUT_TRAITE = 'traite';

    protected $table = 'avis_signalements';

    protected $fillable = [
        'avis_id',
        'signale_par_user_id',
        'motif',
        'details',
        'statut',
        'traite_par_user_id',
        'traite_le',
        'decision',
        'note_moderation',
    ];

    protected $casts = [
        'traite_le' => 'datetime',
    ];

    public function avis()
    {
        return $this->belongsTo(Avis::class);
    }

    public function signalePar()
    {
        return $this->belongsTo(User::class, 'signale_par_user_id');
    }

    public function traitePar()
    {
        return $this->belongsTo(User::class, 'traite_par_user_id');
    }
}
