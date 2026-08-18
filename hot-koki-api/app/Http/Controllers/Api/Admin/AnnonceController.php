<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Annonce;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;

class AnnonceController extends Controller
{
    public function index()
    {
        return response()->json(Annonce::with('produit:id,nom,photo,prix')->orderBy('ordre')->latest('id')->get());
    }

    public function store(Request $request)
    {
        $data = $this->validateData($request);
        if ($request->hasFile('image')) {
            $data['image'] = 'storage/'.$request->file('image')->store('annonces', 'public');
        }

        $annonce = Annonce::create($data);

        return response()->json([
            'message' => 'Annonce créée.',
            'annonce' => $annonce->load('produit:id,nom,photo,prix'),
        ], 201);
    }

    public function update(Request $request, Annonce $annonce)
    {
        $data = $this->validateData($request, true);
        if ($request->boolean('supprimer_image') || $request->hasFile('image')) {
            $this->deleteImage($annonce->image);
            $data['image'] = null;
        }
        if ($request->hasFile('image')) {
            $data['image'] = 'storage/'.$request->file('image')->store('annonces', 'public');
        }
        $annonce->update($data);

        return response()->json([
            'message' => 'Annonce modifiée.',
            'annonce' => $annonce->fresh()->load('produit:id,nom,photo,prix'),
        ]);
    }

    public function destroy(Annonce $annonce)
    {
        $this->deleteImage($annonce->image);
        $annonce->delete();

        return response()->json(['message' => 'Annonce supprimée.']);
    }

    private function validateData(Request $request, bool $update = false): array
    {
        return $request->validate([
            'type' => [$update ? 'sometimes' : 'required', Rule::in(['promotion', 'produit'])],
            'etiquette' => 'nullable|string|max:80',
            'titre' => [$update ? 'sometimes' : 'required', 'string', 'max:255'],
            'description' => 'nullable|string|max:1000',
            'produit_id' => 'nullable|exists:produits,id',
            'active' => 'sometimes|boolean',
            'ordre' => 'sometimes|integer|min:0|max:1000',
            'image' => 'sometimes|nullable|image|mimes:jpeg,jpg,png,webp|max:5120',
            'supprimer_image' => 'sometimes|boolean',
        ], [
            'titre.required' => 'Le titre de l’annonce est obligatoire.',
            'image.image' => 'Le fichier choisi doit être une image.',
            'image.mimes' => 'L’image doit être au format JPEG, PNG ou WebP.',
            'image.max' => 'L’image ne doit pas dépasser 5 Mo.',
        ]);
    }

    private function deleteImage(?string $image): void
    {
        if ($image && str_starts_with($image, 'storage/annonces/')) {
            Storage::disk('public')->delete(substr($image, strlen('storage/')));
        }
    }
}
