<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\PushToken;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class PushTokenController extends Controller
{
    public function store(Request $request)
    {
        $validated = $request->validate([
            'token' => ['required', 'string', 'max:512'],
            'platform' => ['required', Rule::in(['android', 'ios'])],
        ]);

        PushToken::query()->updateOrCreate(
            ['token' => $validated['token']],
            [
                'user_id' => $request->user()->id,
                'access_token_id' => $request->user()->currentAccessToken()?->id,
                'platform' => $validated['platform'],
                'last_seen_at' => now(),
            ],
        );

        return response()->json(['message' => 'Cet appareil recevra les notifications.']);
    }

    public function destroy(Request $request)
    {
        $validated = $request->validate([
            'token' => ['required', 'string', 'max:512'],
        ]);

        $request->user()->pushTokens()
            ->where('token', $validated['token'])
            ->delete();

        return response()->json(['message' => 'Notifications désactivées sur cet appareil.']);
    }
}
