#!/usr/bin/env bash

set -euo pipefail

if [[ "${APP_ENV:-}" != "staging" && "${APP_ENV:-}" != "production" ]]; then
    echo "APP_ENV doit être injecté avec la valeur staging ou production." >&2
    exit 1
fi

composer install --no-dev --prefer-dist --no-interaction --optimize-autoloader
php artisan deploy:check
php artisan migrate --force
php artisan optimize
php artisan queue:restart

echo "Déploiement Laravel terminé pour ${APP_ENV}."
