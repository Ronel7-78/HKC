<!doctype html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{ $verification ? 'Vérification de votre adresse e-mail' : 'Réinitialisation de votre mot de passe' }}</title>
</head>
<body style="margin:0;padding:0;background:#f5f3ef;color:#213226;font-family:Arial,Helvetica,sans-serif;">
    <div style="display:none;max-height:0;overflow:hidden;opacity:0;">
        {{ $verification ? 'Votre code de vérification Hot Koki Chaud' : 'Votre code de réinitialisation Hot Koki Chaud' }}. Valable 10 minutes.
    </div>
    <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="background:#f5f3ef;">
        <tr><td align="center" style="padding:24px 12px;">
            <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="max-width:560px;background:#ffffff;border-radius:18px;">
                <tr><td align="center" style="padding:24px 24px 0;">
                    <img src="{{ $message->embed(public_path('hot-koki-logo.jpeg')) }}" alt="Hot Koki Chaud" width="220" style="display:block;width:220px;max-width:100%;height:auto;border:0;">
                </td></tr>
                <tr><td style="padding:0 32px 32px;">
                    <h1 style="margin:0 0 18px;color:#1f3524;font-size:25px;line-height:1.25;text-align:center;">
                        {{ $verification ? 'Vérifions votre adresse e-mail' : 'Un nouveau mot de passe ?' }}
                    </h1>
                    <p style="margin:0 0 14px;font-size:16px;line-height:1.55;">Bonjour {{ $recipientName }},</p>
                    <p style="margin:0 0 20px;font-size:16px;line-height:1.55;">
                        {{ $verification
                            ? 'Bienvenue chez Hot Koki Chaud ! Saisissez le code ci-dessous dans l’application pour confirmer votre adresse e-mail et accéder à votre compte.'
                            : 'Vous avez demandé à réinitialiser le mot de passe de votre compte Hot Koki Chaud. Saisissez ce code dans l’application pour en choisir un nouveau.' }}
                    </p>
                    <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="background:#fff2e8;border-radius:12px;">
                        <tr><td align="center" style="padding:20px 12px;">
                            <span style="font-size:30px;font-weight:700;letter-spacing:7px;color:#d94b16;">{{ $code }}</span>
                        </td></tr>
                    </table>
                    <p style="margin:18px 0 0;color:#686b67;font-size:14px;line-height:1.5;text-align:center;">
                        Ce code est personnel, utilisable une seule fois et valable 10 minutes. Ne le communiquez à personne.
                    </p>
                    <p style="margin:24px 0 0;font-size:14px;line-height:1.55;">
                        Si vous n’êtes pas à l’origine de cette demande, ignorez ce message : aucun changement ne sera effectué.
                    </p>
                </td></tr>
            </table>
            <p style="max-width:560px;margin:18px 0 0;color:#777a75;font-size:12px;line-height:1.5;text-align:center;">
                © {{ date('Y') }} Hot Koki Chaud · Message automatique, merci de ne pas y répondre.
            </p>
        </td></tr>
    </table>
</body>
</html>
