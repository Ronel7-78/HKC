<?php

namespace App\Notifications;

use App\Models\EmailAuthCode;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldBeEncrypted;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

class EmailAuthenticationCode extends Notification implements ShouldBeEncrypted, ShouldQueue
{
    use Queueable;

    public function __construct(
        private readonly string $code,
        private readonly string $purpose,
    ) {}

    public function via(object $notifiable): array
    {
        return ['mail'];
    }

    public function toMail(object $notifiable): MailMessage
    {
        $verification = $this->purpose === EmailAuthCode::PURPOSE_VERIFY_EMAIL;

        return (new MailMessage)
            ->subject($verification
                ? 'Votre code de vérification · Hot Koki Chaud'
                : 'Réinitialisation de votre mot de passe · Hot Koki Chaud')
            ->view([
                'html' => 'emails.authentication-code',
                'text' => 'emails.authentication-code-text',
            ], [
                'recipientName' => $notifiable->name,
                'code' => $this->code,
                'verification' => $verification,
            ]);
    }
}
