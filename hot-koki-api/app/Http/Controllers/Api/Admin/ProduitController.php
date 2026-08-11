<?php
// app/Http/Controllers/Api/Admin/ProduitController.php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Produit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class ProduitController extends Controller
{
    public function index()
    {
        return response()->json(Produit::with('complements')->get());
    }

    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'nom' => 'required|string|max:255',
            'description' => 'nullable|string',
            'prix' => 'required|numeric|min:0',
            'photo' => 'nullable|string',
            'complements' => 'nullable|array',
            'complements.*' => 'exists:complements,id',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $produit = Produit::create($request->only(['nom', 'description', 'prix', 'photo']));

        if ($request->has('complements')) {
            $produit->complements()->sync($request->complements);
        }

        return response()->json([
            'message' => 'Produit créé',
            'produit' => $produit->load('complements'),
        ], 201);
    }

    public function show($id)
    {
        return response()->json(Produit::with('complements')->findOrFail($id));
    }

    public function update(Request $request, $id)
    {
        $produit = Produit::findOrFail($id);

        $validator = Validator::make($request->all(), [
            'nom' => 'sometimes|string|max:255',
            'description' => 'sometimes|nullable|string',
            'prix' => 'sometimes|numeric|min:0',
            'photo' => 'sometimes|nullable|string',
            'complements' => 'sometimes|array',
            'complements.*' => 'exists:complements,id',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $produit->update($request->only(['nom', 'description', 'prix', 'photo']));

        if ($request->has('complements')) {
            $produit->complements()->sync($request->complements);
        }

        return response()->json([
            'message' => 'Produit mis à jour',
            'produit' => $produit->load('complements'),
        ]);
    }

    public function destroy($id)
    {
        Produit::findOrFail($id)->delete();
        return response()->json(['message' => 'Produit supprimé']);
    }
}