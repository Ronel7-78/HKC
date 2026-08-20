<?php

namespace App\Services;

use App\Models\EmailAuthCode;
use App\Models\User;
use App\Notifications\EmailAuthenticationCode;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class EmailCodeService
{
    public function issue(User $user, string $purpose): void
    {
        $last = EmailAuthCode::query()
            ->where('user_id', $user->id)
            ->where('purpose', $purpose)
            ->latest('id')
            ->first();

        if ($last?->created_at?->isAfter(now()->subMinute())) {
            throw ValidationException::withMessages([
                'email' => 'Patientez une minute avant de demander un nouveau code.',
            ]);
        }

        $code = (string) random_int(100000, 999999);

        DB::transaction(function () use ($user, $purpose, $code): void {
            EmailAuthCode::query()
                ->where('user_id', $user->id)
                ->where('purpose', $purpose)
                ->whereNull('used_at')
                ->update(['used_at' => now()]);

            EmailAuthCode::create([
                'user_id' => $user->id,
                'purpose' => $purpose,
                'code_hash' => Hash::make($code),
                'expires_at' => now()->addMinutes(10),
            ]);
        });

        $user->notify(new EmailAuthenticationCode($code, $purpose));
    }

    public function consume(User $user, string $purpose, string $code): void
    {
        DB::transaction(function () use ($user, $purpose, $code): void {
            $record = EmailAuthCode::query()
                ->where('user_id', $user->id)
                ->where('purpose', $purpose)
                ->whereNull('used_at')
                ->latest('id')
                ->lockForUpdate()
                ->first();

            if (! $record || $record->expires_at->isPast()) {
                throw ValidationException::withMessages([
                    'code' => 'Ce code a expiré. Demandez-en un nouveau.',
                ]);
            }

            if ($record->attempts >= 5) {
                throw ValidationException::withMessages([
                    'code' => 'Trop de tentatives. Demandez un nouveau code.',
                ]);
            }

            if (! Hash::check($code, $record->code_hash)) {
                $record->increment('attempts');
                throw ValidationException::withMessages([
                    'code' => 'Le code saisi est incorrect.',
                ]);
            }

            $record->update(['used_at' => now()]);
        });
    }
}
