<!doctype html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="robots" content="noindex,nofollow">
    <title>{{ $success ? 'Paiement transmis' : 'Paiement annulé' }} — Hot Koki</title>
    <style>
        * { box-sizing: border-box; }
        body {
            margin: 0;
            min-height: 100vh;
            display: grid;
            place-items: center;
            padding: 24px;
            background: #f4f3f1;
            color: #1f3524;
            font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        }
        main {
            width: min(100%, 480px);
            padding: 32px 26px;
            text-align: center;
            background: #fff;
            border: 1px solid #e8e5e1;
            border-radius: 24px;
            box-shadow: 0 16px 42px rgba(31, 53, 36, .10);
        }
        .icon {
            width: 64px;
            height: 64px;
            display: grid;
            place-items: center;
            margin: 0 auto 18px;
            border-radius: 50%;
            background: {{ $success ? '#e7eee4' : '#ffebe3' }};
            color: {{ $success ? '#2e4e36' : '#d94b16' }};
            font-size: 32px;
            font-weight: 900;
        }
        h1 { margin: 0 0 12px; font-size: 26px; }
        p { margin: 0; color: #6b6864; line-height: 1.55; }
        strong { color: #1f3524; }
    </style>
</head>
<body>
<main>
    <div class="icon" aria-hidden="true">{{ $success ? '✓' : '×' }}</div>
    <h1>{{ $success ? 'Demande transmise' : 'Paiement annulé' }}</h1>
    <p>
        @if ($success)
            Revenez dans <strong>Hot Koki</strong> : l’application vérifiera le statut final auprès d’Orange Money.
        @else
            Aucun succès de paiement n’a été confirmé. Vous pouvez revenir dans <strong>Hot Koki</strong> et réessayer.
        @endif
    </p>
</main>
</body>
</html>
