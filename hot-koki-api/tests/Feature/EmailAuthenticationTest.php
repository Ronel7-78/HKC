<?php

namespace Tests\Feature;

use App\Models\EmailAuthCode;
use App\Models\User;
use App\Notifications\EmailAuthenticationCode;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Notification;
use Tests\TestCase;

class EmailAuthenticationTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        config()->set('email_auth.verification_enabled', true);
        Notification::fake();
    }

    public function test_client_ne_recoit_un_token_quapres_verification_de_son_email(): void
    {
        $response = $this->postJson('/api/register', $this->registration())
            ->assertCreated()
            ->assertJsonMissingPath('token')
            ->assertJsonPath('verification_requise', true);

        $user = User::findOrFail($response->json('user.id'));
        $this->assertNull($user->email_verified_at);

        $this->postJson('/api/login', [
            'email' => $user->email,
            'password' => 'Password-123',
            'conditions_acceptees' => true,
        ])->assertForbidden()->assertJsonPath('code', 'EMAIL_NON_VERIFIE');

        $code = $this->sentCode($user, EmailAuthCode::PURPOSE_VERIFY_EMAIL);
        $this->postJson('/api/email/verify', ['email' => $user->email, 'code' => '000000'])
            ->assertUnprocessable();

        $this->postJson('/api/email/verify', ['email' => $user->email, 'code' => $code])
            ->assertOk()
            ->assertJsonStructure(['token', 'user'])
            ->assertJsonPath('user.email', $user->email);

        $this->assertNotNull($user->fresh()->email_verified_at);
        $this->postJson('/api/email/verify', ['email' => $user->email, 'code' => $code])
            ->assertUnprocessable();
    }

    public function test_inscription_et_connexion_fonctionnent_sans_smtp_quand_la_verification_est_desactivee(): void
    {
        config()->set('email_auth.verification_enabled', false);

        $response = $this->postJson('/api/register', $this->registration())
            ->assertCreated()
            ->assertJsonPath('verification_requise', false)
            ->assertJsonStructure(['token', 'user']);

        $user = User::findOrFail($response->json('user.id'));
        $this->assertNull($user->email_verified_at);
        Notification::assertNothingSent();

        $this->postJson('/api/login', [
            'email' => $user->email,
            'password' => 'Password-123',
            'conditions_acceptees' => true,
        ])->assertOk()->assertJsonStructure(['token']);
    }

    public function test_reset_password_est_neutre_revoque_les_sessions_et_consomme_le_code(): void
    {
        $user = User::factory()->create([
            'role' => 'client',
            'email' => 'client@hotkoki.test',
            'email_verified_at' => now(),
            'password' => 'Ancien-password-123',
        ]);
        $user->client()->create(['nom' => 'Client']);
        $oldToken = $user->createToken('ancien')->plainTextToken;

        $this->postJson('/api/forgot-password', ['email' => 'inconnu@hotkoki.test'])
            ->assertAccepted();
        $this->postJson('/api/forgot-password', ['email' => $user->email])
            ->assertAccepted();

        $code = $this->sentCode($user, EmailAuthCode::PURPOSE_RESET_PASSWORD);
        $payload = [
            'email' => $user->email,
            'code' => $code,
            'password' => 'Nouveau-password-456',
            'password_confirmation' => 'Nouveau-password-456',
        ];
        $this->postJson('/api/reset-password', $payload)->assertOk();
        $this->assertDatabaseMissing('personal_access_tokens', [
            'token' => hash('sha256', explode('|', $oldToken, 2)[1]),
        ]);
        $this->postJson('/api/reset-password', $payload)->assertUnprocessable();

        $this->postJson('/api/login', [
            'email' => $user->email,
            'password' => 'Nouveau-password-456',
            'conditions_acceptees' => true,
        ])->assertOk()->assertJsonStructure(['token']);
    }

    private function sentCode(User $user, string $purpose): string
    {
        $notification = Notification::sent($user, EmailAuthenticationCode::class)
            ->first(fn (EmailAuthenticationCode $item) => (new \ReflectionProperty($item, 'purpose'))->getValue($item) === $purpose
            );
        $this->assertNotNull($notification);

        return (new \ReflectionProperty($notification, 'code'))->getValue($notification);
    }

    private function registration(): array
    {
        return [
            'name' => 'Client Email',
            'email' => 'CLIENT@hotkoki.test',
            'telephone' => '237677123456',
            'password' => 'Password-123',
            'password_confirmation' => 'Password-123',
            'adresse_texte' => 'Bertoua',
            'latitude' => 4.58,
            'longitude' => 13.68,
            'conditions_acceptees' => true,
        ];
    }
}
