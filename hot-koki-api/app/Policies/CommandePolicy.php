<?php

namespace App\Policies;

use App\Models\Commande;
use App\Models\User;
use Illuminate\Auth\Access\Response;

class CommandePolicy
{
    public function client(User $user, Commande $commande): Response
    {
        return $user->isClient() && $commande->client_id === $user->client?->id
            ? Response::allow()
            : Response::denyAsNotFound();
    }

    public function vendeur(User $user, Commande $commande): Response
    {
        return $user->isVendeur() && $commande->vendeur_id === $user->vendeur?->id
            ? Response::allow()
            : Response::denyAsNotFound();
    }

    public function administrer(User $user, Commande $commande): Response
    {
        return $user->isAdmin()
            ? Response::allow()
            : Response::denyAsNotFound();
    }
}
