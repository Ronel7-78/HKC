<?php

use App\Http\Controllers\Api\Admin\ComplementController;
use App\Http\Controllers\Api\Admin\ProduitController as AdminProduitController;
use App\Http\Controllers\Api\AdminController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\ClientController;
use App\Http\Controllers\Api\CommandeController;
use App\Http\Controllers\Api\VendeurController;
use App\Http\Controllers\Api\VendeurProduitController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

// Routes publiques
Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);

// Routes de l'utilisateur authentifie
Route::middleware('auth:sanctum')->group(function () {
    Route::get('/user', function (Request $request) {
        return $request->user();
    });
    Route::get('/me', [AuthController::class, 'me']);
    Route::post('/logout', [AuthController::class, 'logout']);

    // Routes du client
    Route::prefix('client')->group(function () {
        Route::get('/profile', [ClientController::class, 'show']);
        Route::put('/profile', [ClientController::class, 'update']);
    });

    // Routes du vendeur
    Route::prefix('vendeur')->group(function () {
        Route::get('/profile', [VendeurController::class, 'show']);
        Route::put('/profile', [VendeurController::class, 'update']);
        Route::patch('/disponibilite', [VendeurController::class, 'updateDisponibilite']);

        // Stock du vendeur
        Route::get('/produits', [VendeurProduitController::class, 'index']);
        Route::patch('/produits/{produitId}/statut', [VendeurProduitController::class, 'updateStatut']);
    });

    // Routes des commandes
    Route::prefix('commandes')->group(function () {
        Route::post('/preview', [CommandeController::class, 'preview']);
        Route::post('/', [CommandeController::class, 'store']);
        Route::get('/', [CommandeController::class, 'index']);
    });
});

// Routes de l'admin
Route::middleware(['auth:sanctum', 'isAdmin'])->prefix('admin')->group(function () {
    Route::get('/profile', [AdminController::class, 'show']);
    Route::put('/profile', [AdminController::class, 'update']);

    // Catalogue (admin uniquement)
    Route::apiResource('produits', AdminProduitController::class);
    Route::get('/complements', [ComplementController::class, 'index']);
    Route::post('/complements', [ComplementController::class, 'store']);
    Route::delete('/complements/{id}', [ComplementController::class, 'destroy']);
});
