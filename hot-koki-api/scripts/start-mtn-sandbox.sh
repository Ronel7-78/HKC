#!/usr/bin/env bash

set -euo pipefail

if [[ ! -t 0 ]]; then
    echo "Ce lanceur doit être exécuté depuis un terminal interactif." >&2
    exit 1
fi

read -r -p "URL HTTPS publique du callback : " MTN_CALLBACK_URL
read -r -s -p "MTN Collections Primary Key : " MTN_SUBSCRIPTION_KEY
echo
read -r -s -p "MTN API User : " MTN_API_USER
echo
read -r -s -p "MTN API Key : " MTN_API_KEY
echo

if [[ "$MTN_CALLBACK_URL" != https://* ]]; then
    echo "Le callback doit utiliser HTTPS." >&2
    exit 1
fi

export MTN_MOMO_BASE_URL="https://sandbox.momodeveloper.mtn.com"
export MTN_MOMO_TARGET_ENVIRONMENT="sandbox"
export MTN_MOMO_CURRENCY="EUR"
export MTN_MOMO_CALLBACK_BASE_URL="$MTN_CALLBACK_URL"
export MTN_MOMO_SUBSCRIPTION_KEY="$MTN_SUBSCRIPTION_KEY"
export MTN_MOMO_API_USER="$MTN_API_USER"
export MTN_MOMO_API_KEY="$MTN_API_KEY"

unset MTN_SUBSCRIPTION_KEY MTN_API_USER MTN_API_KEY MTN_CALLBACK_URL

php artisan config:clear --quiet

php artisan serve --host=127.0.0.1 --port=8000 &
SERVER_PID=$!
php artisan queue:work --queue=paiements,default --tries=3 --timeout=60 &
QUEUE_PID=$!

cleanup() {
    kill "$SERVER_PID" "$QUEUE_PID" 2>/dev/null || true
}

trap cleanup EXIT INT TERM

echo "API et worker démarrés. Ctrl+C pour arrêter les deux."
wait -n "$SERVER_PID" "$QUEUE_PID"
