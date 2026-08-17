<?php
// app/Http/Controllers/Api/AdminController.php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rule;

class AdminController extends Controller
{
    public function show(Request $request)
    {
        $admin = $request->user()->admin;

        if (! $admin) {
            return response()->json(['message' => 'Profil admin introuvable'], 404);
        }

        return response()->json(['admin' => $admin, 'user' => $request->user()]);
    }

    public function update(Request $request)
    {
        $admin = $request->user()->admin;

        if (! $admin) {
            return response()->json(['message' => 'Profil admin introuvable'], 404);
        }

        $validator = Validator::make($request->all(), [
            'name' => 'sometimes|required|string|max:255',
            'email' => ['sometimes', 'required', 'email', Rule::unique('users')->ignore($request->user()->id)],
            'telephone' => ['sometimes', 'nullable', 'string', Rule::unique('users')->ignore($request->user()->id)],
            'nom' => 'sometimes|string|max:255',
            'prenom' => 'sometimes|nullable|string|max:255',
            'current_password' => 'required_with:password|string',
            'password' => 'sometimes|string|min:8|confirmed',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $validated = $validator->validated();
        if (isset($validated['password']) && ! Hash::check($validated['current_password'], $request->user()->password)) {
            return response()->json(['message' => 'Le mot de passe actuel est incorrect.'], 422);
        }

        DB::transaction(function () use ($admin, $request, $validated) {
            $userData = collect($validated)->only(['name', 'email', 'telephone'])->all();
            if (isset($validated['password'])) {
                $userData['password'] = Hash::make($validated['password']);
            }
            $request->user()->update($userData);
            $admin->update(collect($validated)->only(['nom', 'prenom'])->all());
        });

        return response()->json([
            'message' => 'Profil administrateur mis à jour.',
            'admin' => $admin->fresh(),
            'user' => $request->user()->fresh(),
        ]);
    }
}
