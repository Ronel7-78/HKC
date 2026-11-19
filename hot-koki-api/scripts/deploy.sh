#!/usr/bin/env bash

# Stoppe immédiatement le déploiement à la première erreur.
set -euo pipefail

# Empêche un déploiement sur un environnement non identifié.
if [[ "${APP_ENV:-}" != "staging" && "${APP_ENV:-}" != "production" ]]; then
    echo "APP_ENV doit être staging ou production." >&2
    exit 1
fi

# Vide les anciens caches Laravel.
php artisan optimize:clear

# Installe les dépendances exactes du projet.
composer install --no-dev --prefer-dist --no-interaction --optimize-autoloader

# Vérifie HTTPS, base de données, queue, secrets et paiement.
php artisan deploy:check

# Applique les migrations, y compris celles de sécurité/idempotence.
php artisan migrate --force

# Reconstruit les caches avec le nouveau code et le nouveau .env.
php artisan optimize

# Redémarre proprement les workers Laravel.
php artisan queue:restart

# Vérifie CamPay sans créer de transaction.
if [[ "${RUN_PAYMENT_PREFLIGHT:-false}" == "true" ]]; then
    php artisan campay:test-config
fi

echo "Déploiement Laravel terminé pour ${APP_ENV}."