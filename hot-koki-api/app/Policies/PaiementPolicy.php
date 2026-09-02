<?php

namespace App\Policies;

use App\Models\Paiement;
use App\Models\User;
use Illuminate\Auth\Access\Response;

class PaiementPolicy
{
    public function client(User $user, Paiement $paiement): Response
    {
        return $user->isClient() && $paiement->commande->client_id === $user->client?->id
            ? Response::allow()
            : Response::denyAsNotFound();
    }

    public function administrer(User $user, Paiement $paiement): Response
    {
        return $user->isAdmin()
            ? Response::allow()
            : Response::denyAsNotFound();
    }
}
