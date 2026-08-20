<?php

// app/Http/Controllers/Api/Admin/ComplementController.php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Complement;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class ComplementController extends Controller
{
    public function index()
    {
        return response()->json(Complement::all());
    }

    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'nom' => 'required|string|max:255|unique:complements,nom',
        ], [
            'nom.required' => 'Le nom du complément est obligatoire.',
            'nom.unique' => 'Ce complément existe déjà.',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $complement = Complement::create($request->only('nom'));

        return response()->json(['message' => 'Complément créé', 'complement' => $complement], 201);
    }

    public function destroy(string $id)
    {
        Complement::where('public_id', $id)->firstOrFail()->delete();

        return response()->json(['message' => 'Complément supprimé']);
    }
}
