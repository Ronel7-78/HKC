<?php

use App\Http\Controllers\Api\AdminController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\ClientController;
use App\Http\Controllers\Api\VendeurController;

Route::get('/user', function (Request $request) {
    return $request->user();
})->middleware('auth:sanctum');


//Route Users
Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/me', [AuthController::class, 'me']);
});

// Route Clients
// routes/api.php


Route::middleware('auth:sanctum')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/me', [AuthController::class, 'me']);

    Route::get('/client/profile', [ClientController::class, 'show']);
    Route::put('/client/profile', [ClientController::class, 'update']);

    //routes du vendeur
    Route::get('/vendeur/profile', [VendeurController::class, 'show']);
    Route::put('/vendeur/profile', [VendeurController::class, 'update']);
    Route::patch('/vendeur/disponibilite', [VendeurController::class, 'updateDisponibilite']);
});


// Routes de l'admin

Route::middleware(['auth:sanctum', 'isAdmin'])->group(function () {
    Route::get('/admin/profile', [AdminController::class, 'show']);
    Route::put('/admin/profile', [AdminController::class, 'update']);
});