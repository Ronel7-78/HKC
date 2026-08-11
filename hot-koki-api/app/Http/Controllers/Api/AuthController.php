<?php
// app/Http/Controllers/Api/AuthController.php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;
use App\Models\Client;
use App\Models\Vendeur;
use App\Models\Admin;

class AuthController extends Controller
{
    // Inscription
   public function register(Request $request){

    $validator = Validator::make($request->all(), [
        'name' => 'required|string|max:255',
        'email' => 'required|string|email|max:255|unique:users',
        'telephone' => 'required|string|unique:users',
        'password' => 'required|string|min:8|confirmed',
        'role' => 'required|in:client,vendeur,admin',
    ]);

    if ($validator->fails()) {
        return response()->json(['errors' => $validator->errors()], 422);
    }

    $user = User::create([
        'name' => $request->name,
        'email' => $request->email,
        'telephone' => $request->telephone,
        'password' => Hash::make($request->password),
        'role' => $request->role,
    ]);

    // Création automatique du profil correspondant au rôle
    match ($request->role) {
        'client' => Client::create(['user_id' => $user->id, 'nom' => $request->name]),
        'vendeur' => Vendeur::create([ 'user_id' => $user->id,'nom_boutique' => $request->name,]),
        'admin' => Admin::create(['user_id' => $user->id, 'nom' => $request->name]),
    };

    $token = $user->createToken('auth_token')->plainTextToken;

    return response()->json([
        'message' => 'Compte créé avec succès',
        'user' => $user->load($request->role), // recharge la relation pour l'inclure dans la réponse
        'token' => $token,
    ], 201);
}

    // Connexion
    public function login(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'email' => 'required|email',
            'password' => 'required',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $user = User::where('email', $request->email)->first();

        if (!$user || !Hash::check($request->password, $user->password)) {
            return response()->json(['message' => 'Identifiants incorrects'], 401);
        }

        $token = $user->createToken('auth_token')->plainTextToken;

        return response()->json([
            'message' => 'Connexion réussie',
            'user' => $user,
            'token' => $token,
        ]);
    }

    // Déconnexion
    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => 'Déconnexion réussie']);
    }

    // Récupérer l'utilisateur connecté (utile pour Flutter au démarrage de l'app)
    public function me(Request $request)
    {
        return response()->json($request->user());
    }
}