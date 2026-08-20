<?php

// app/Http/Controllers/Api/Admin/ProduitController.php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Produit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
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
            'photo' => 'nullable|image|mimes:jpeg,jpg,png,webp|max:5120',
            'complements' => 'nullable|array',
            'complements.*' => 'exists:complements,id',
            'synchroniser_complements' => 'sometimes|boolean',
        ], $this->messages());

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $data = $request->only(['nom', 'description', 'prix']);
        if ($request->hasFile('photo')) {
            $data['photo'] = 'storage/'.$request->file('photo')->store('produits', 'public');
        }

        $produit = Produit::create($data);

        if ($request->boolean('synchroniser_complements') || $request->has('complements')) {
            $produit->complements()->sync($request->input('complements', []));
        }

        return response()->json([
            'message' => 'Produit créé',
            'produit' => $produit->load('complements'),
        ], 201);
    }

    public function show(string $id)
    {
        return response()->json(Produit::with('complements')->where('public_id', $id)->firstOrFail());
    }

    public function update(Request $request, string $id)
    {
        $produit = Produit::where('public_id', $id)->firstOrFail();

        $validator = Validator::make($request->all(), [
            'nom' => 'sometimes|string|max:255',
            'description' => 'sometimes|nullable|string',
            'prix' => 'sometimes|numeric|min:0',
            'photo' => 'sometimes|nullable|image|mimes:jpeg,jpg,png,webp|max:5120',
            'supprimer_photo' => 'sometimes|boolean',
            'complements' => 'sometimes|array',
            'complements.*' => 'exists:complements,id',
            'synchroniser_complements' => 'sometimes|boolean',
        ], $this->messages());

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $data = $request->only(['nom', 'description', 'prix']);
        if ($request->boolean('supprimer_photo') || $request->hasFile('photo')) {
            $this->deleteManagedPhoto($produit->photo);
            $data['photo'] = null;
        }
        if ($request->hasFile('photo')) {
            $data['photo'] = 'storage/'.$request->file('photo')->store('produits', 'public');
        }

        $produit->update($data);

        if ($request->boolean('synchroniser_complements') || $request->has('complements')) {
            $produit->complements()->sync($request->input('complements', []));
        }

        return response()->json([
            'message' => 'Produit mis à jour',
            'produit' => $produit->load('complements'),
        ]);
    }

    public function destroy(string $id)
    {
        $produit = Produit::where('public_id', $id)->firstOrFail();
        $this->deleteManagedPhoto($produit->photo);
        $produit->delete();

        return response()->json(['message' => 'Produit supprimé']);
    }

    private function messages(): array
    {
        return [
            'required' => 'Le champ :attribute est obligatoire.',
            'prix.numeric' => 'Le prix doit être un nombre valide.',
            'prix.min' => 'Le prix ne peut pas être négatif.',
            'photo.image' => 'Le fichier choisi doit être une image.',
            'photo.mimes' => 'L’image doit être au format JPEG, PNG ou WebP.',
            'photo.max' => 'L’image ne doit pas dépasser 5 Mo.',
            'complements.*.exists' => 'Un complément sélectionné n’existe plus.',
        ];
    }

    private function deleteManagedPhoto(?string $photo): void
    {
        if ($photo && str_starts_with($photo, 'storage/produits/')) {
            Storage::disk('public')->delete(substr($photo, strlen('storage/')));
        }
    }
}
