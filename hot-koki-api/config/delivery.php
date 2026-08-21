<?php

return [
    // La distance est mesuree entre la position du vendeur au moment de la
    // commande et l'adresse de livraison choisie par le client.
    'free_radius_km' => (float) env('DELIVERY_FREE_RADIUS_KM', 3),
    'flat_fee_xaf' => (int) env('DELIVERY_FLAT_FEE_XAF', 500),
];
