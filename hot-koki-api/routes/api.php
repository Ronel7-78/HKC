<?php

use App\Http\Controllers\Api\AccueilController;
use App\Http\Controllers\Api\Admin\AnnonceController as AdminAnnonceController;
use App\Http\Controllers\Api\Admin\ComplementController;
use App\Http\Controllers\Api\Admin\DashboardController as AdminDashboardController;
use App\Http\Controllers\Api\Admin\ProduitController as AdminProduitController;
use App\Http\Controllers\Api\Admin\VendeurController as AdminVendeurController;
use App\Http\Controllers\Api\AdminController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\AvisController;
use App\Http\Controllers\Api\CatalogueController;
use App\Http\Controllers\Api\ClientController;
use App\Http\Controllers\Api\ClientVendeurController;
use App\Http\Controllers\Api\CommandeController;
use App\Http\Controllers\Api\MtnMomoWebhookController;
use App\Http\Controllers\Api\NotificationController;
use App\Http\Controllers\Api\PaiementController;
use App\Http\Controllers\Api\VendeurCommandeController;
use App\Http\Controllers\Api\VendeurController;
use App\Http\Controllers\Api\VendeurDashboardController;
use App\Http\Controllers\Api\VendeurProduitController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

// Routes publiques
Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);
Route::get('/catalogue', [CatalogueController::class, 'index']);
Route::get('/accueil', AccueilController::class);
Route::match(['post', 'put'], '/webhooks/mtn-momo/{transactionHash}', MtnMomoWebhookController::class)
    ->where('transactionHash', '[A-Za-z0-9]{64}');

// Routes de l'utilisateur authentifie
Route::middleware('auth:sanctum')->group(function () {
    Route::get('/user', function (Request $request) {
        return $request->user();
    });
    Route::get('/me', [AuthController::class, 'me']);
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/notifications', [NotificationController::class, 'index']);
    Route::patch('/notifications/tout-lire', [NotificationController::class, 'toutMarquerLu']);
    Route::patch('/notifications/{notification}/lire', [NotificationController::class, 'marquerLue']);

    // Routes reservees au client
    Route::middleware('role:client')->prefix('client')->group(function () {
        Route::get('/profile', [ClientController::class, 'show']);
        Route::put('/profile', [ClientController::class, 'update']);
        Route::get('/vendeurs', [ClientVendeurController::class, 'index']);
        Route::get('/vendeurs/{vendeur}', [ClientVendeurController::class, 'show']);
        Route::get('/avis', [AvisController::class, 'index']);
        Route::get('/catalogue', [CatalogueController::class, 'client']);
    });

    // Routes reservees au vendeur
    Route::middleware('role:vendeur')->prefix('vendeur')->group(function () {
        Route::get('/dashboard', [VendeurDashboardController::class, 'dashboard']);
        Route::get('/avis', [VendeurDashboardController::class, 'avis']);
        Route::get('/profile', [VendeurController::class, 'show']);
        Route::put('/profile', [VendeurController::class, 'update']);
        Route::patch('/disponibilite', [VendeurController::class, 'updateDisponibilite']);

        // Stock du vendeur
        Route::get('/produits', [VendeurProduitController::class, 'index']);
        Route::patch('/produits/{produitId}/statut', [VendeurProduitController::class, 'updateStatut']);

        // Commandes affectees au vendeur authentifie
        Route::get('/commandes', [VendeurCommandeController::class, 'index']);
        Route::get('/commandes/{commande}', [VendeurCommandeController::class, 'show']);
        Route::patch('/commandes/{commande}/statut', [VendeurCommandeController::class, 'updateStatut']);
    });

    // Routes de commande reservees au client
    Route::middleware('role:client')->prefix('commandes')->group(function () {
        Route::post('/preview', [CommandeController::class, 'preview']);
        Route::post('/', [CommandeController::class, 'store']);
        Route::get('/', [CommandeController::class, 'index']);
        Route::get('/{commande}', [CommandeController::class, 'show']);
        Route::patch('/{commande}/annuler', [CommandeController::class, 'annuler']);
        Route::post('/{commande}/paiements', [PaiementController::class, 'store']);
        Route::post('/{commande}/avis', [AvisController::class, 'store']);
    });

    Route::middleware('role:client')->get('/paiements/{paiement}', [PaiementController::class, 'show']);
    Route::middleware('role:client')->post('/paiements/{paiement}/synchroniser', [PaiementController::class, 'synchroniser']);
});

// Routes de l'admin
Route::middleware(['auth:sanctum', 'isAdmin'])->prefix('admin')->group(function () {
    Route::get('/dashboard', AdminDashboardController::class);
    Route::get('/commandes', [AdminDashboardController::class, 'commandes']);
    Route::get('/profile', [AdminController::class, 'show']);
    Route::put('/profile', [AdminController::class, 'update']);

    // Gestion des vendeurs par l'administrateur uniquement
    Route::apiResource('vendeurs', AdminVendeurController::class);

    // Catalogue (admin uniquement)
    Route::apiResource('produits', AdminProduitController::class);
    Route::apiResource('annonces', AdminAnnonceController::class)->except('show');
    Route::get('/complements', [ComplementController::class, 'index']);
    Route::post('/complements', [ComplementController::class, 'store']);
    Route::delete('/complements/{id}', [ComplementController::class, 'destroy']);
});
