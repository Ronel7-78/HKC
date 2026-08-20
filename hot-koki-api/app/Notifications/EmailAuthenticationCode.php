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
                ? 'Confirmez votre adresse email Hot Koki'
                : 'Code de réinitialisation Hot Koki')
            ->greeting('Bonjour '.$notifiable->name.',')
            ->line($verification
                ? 'Utilisez ce code pour confirmer que cette adresse email vous appartient.'
                : 'Utilisez ce code pour choisir un nouveau mot de passe.')
            ->line('Votre code : '.$this->code)
            ->line('Ce code expire dans 10 minutes et ne peut être utilisé qu’une fois.')
            ->line('Si vous n’êtes pas à l’origine de cette demande, ignorez cet email.');
    }
}
