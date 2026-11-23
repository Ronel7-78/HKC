#!/usr/bin/env bash

# Stoppe immédiatement le déploiement à la première erreur.
set -euo pipefail

# Les fichiers crees pendant le deploiement restent accessibles a PHP-FPM via
# le groupe www-data. Les secrets de storage/app/secure ne sont jamais vises.
umask 0002

# Empêche un déploiement sur un environnement non identifié.
if [[ "${APP_ENV:-}" != "staging" && "${APP_ENV:-}" != "production" ]]; then
    echo "APP_ENV doit être staging ou production." >&2
    exit 1
fi

# Laravel doit pouvoir creer ses caches et ses journaux depuis le processus
# PHP-FPM, qui n'est pas le meme utilisateur que le deploiement.
mkdir -p storage/logs storage/framework/cache storage/framework/sessions storage/framework/views bootstrap/cache
# Les médias envoyés par les administrateurs (plats et annonces) ne sont pas
# stockés dans Git. Ils doivent donc être présents et accessibles après chaque
# déploiement, même sur une installation fraîche.
mkdir -p storage/app/public/produits storage/app/public/annonces
find storage/logs storage/framework bootstrap/cache -type d -exec chmod 2775 {} +
find storage/logs storage/framework bootstrap/cache -type f -exec chmod 0664 {} +
find storage/app/public -type d -exec chmod 2775 {} +
find storage/app/public -type f -exec chmod 0664 {} +

# Vide les anciens caches Laravel.
php artisan optimize:clear

# Installe les dépendances exactes du projet.
composer install --no-dev --prefer-dist --no-interaction --optimize-autoloader

# Vérifie HTTPS, base de données, queue, secrets et paiement.
php artisan deploy:check

# Applique les migrations, y compris celles de sécurité/idempotence.
php artisan migrate --force

# Le lien public vers les médias utilisateur est persistant et ne doit jamais
# dépendre du contenu transféré par CI. Un lien symbolique cassé doit être
# recréé : l'ancien test le laissait en place et les images devenaient alors
# inaccessibles après un déplacement du dossier de déploiement.
if [[ -L public/storage && ! -e public/storage ]]; then
    rm public/storage
fi

if [[ ! -e public/storage ]]; then
    php artisan storage:link
fi

if [[ ! -L public/storage || ! -d public/storage ]]; then
    echo "Le lien public/storage est invalide : les médias ne peuvent pas être servis." >&2
    exit 1
fi

# Reconstruit les caches avec le nouveau code et le nouveau .env.
php artisan optimize

# Redémarre proprement les workers Laravel.
php artisan queue:restart

# Vérifie CamPay sans créer de transaction.
if [[ "${RUN_PAYMENT_PREFLIGHT:-false}" == "true" ]]; then
    php artisan campay:test-config
fi

echo "Déploiement Laravel terminé pour ${APP_ENV}."
