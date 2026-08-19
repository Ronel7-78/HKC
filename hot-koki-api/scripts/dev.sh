#!/usr/bin/env bash

set -euo pipefail

PIDS=()

cleanup() {
    if (( ${#PIDS[@]} > 0 )); then
        kill "${PIDS[@]}" 2>/dev/null || true
        wait "${PIDS[@]}" 2>/dev/null || true
    fi
}

trap cleanup EXIT INT TERM

php artisan config:clear --quiet

if ! php -r '$socket = @stream_socket_server("tcp://127.0.0.1:8000", $code, $message); if (! $socket) { exit(1); } fclose($socket);'; then
    echo "Impossible de démarrer : le port 8000 est déjà utilisé." >&2
    echo "Arrêtez l’ancien serveur Laravel avec Ctrl+C, puis réessayez." >&2
    exit 1
fi

if ! php artisan migrate:status --no-ansi >/dev/null 2>&1; then
    echo "Impossible de démarrer : Laravel ne parvient pas à joindre la base de données." >&2
    echo "Vérifiez que MySQL est démarré et que les variables DB_* du fichier .env sont correctes." >&2
    exit 1
fi

if ! php artisan mtn:check-env; then
    echo "Complétez les variables indiquées dans .env, puis relancez composer dev." >&2
    exit 1
fi

php artisan serve --host=0.0.0.0 --port=8000 &
PIDS+=("$!")

php artisan queue:work --queue=paiements,default --tries=3 --timeout=60 &
PIDS+=("$!")

php artisan schedule:work &
PIDS+=("$!")

php artisan pail --timeout=0 &
PIDS+=("$!")

echo
echo "Hot Koki démarré : API, paiements, polling et logs."
echo "API locale : http://127.0.0.1:8000"
echo "Téléphone : utilisez l’adresse IP locale du PC, par exemple http://192.168.1.112:8000"
echo "Arrêt propre : Ctrl+C"
echo

wait -n "${PIDS[@]}"
