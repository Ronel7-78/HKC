<?php
// app/Http/Controllers/Api/AdminController.php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class AdminController extends Controller
{
    public function show(Request $request)
    {
        $admin = $request->user()->admin;

        if (!$admin) {
            return response()->json(['message' => 'Profil admin introuvable'], 404);
        }

        return response()->json($admin);
    }

    public function update(Request $request)
    {
        $admin = $request->user()->admin;

        if (!$admin) {
            return response()->json(['message' => 'Profil admin introuvable'], 404);
        }

        $validator = Validator::make($request->all(), [
            'nom' => 'sometimes|string|max:255',
            'prenom' => 'sometimes|nullable|string|max:255',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $admin->update($validator->validated());

        return response()->json(['message' => 'Profil mis à jour', 'admin' => $admin]);
    }
}