# Environnements Hot Koki

## Backend Laravel

Le serveur doit fournir PHP 8.3+, MySQL/MariaDB, Redis, HTTPS et un stockage
objet compatible S3. Les secrets sont configurés dans le gestionnaire de
secrets de l’hébergeur, jamais copiés dans le dépôt.

Services permanents :

- serveur PHP derrière Nginx/Caddy ;
- `php artisan queue:work --queue=paiements,default --tries=3 --timeout=60` ;
- `php artisan schedule:run` chaque minute ;
- certificat HTTPS avec renouvellement automatique.

Le déploiement exécute `scripts/deploy.sh`. Les domaines retenus sont :

- site public / URL à communiquer dans les dossiers KYC : `https://hotkokichaud.digital` ;
- API de production : `https://api.hotkokichaud.digital` ;
- API de staging : `https://api-staging.hotkokichaud.digital`.

Avant la première mise en ligne, créer une `APP_KEY` différente du staging,
provisionner une base, Redis et un stockage objet isolés, puis injecter les
secrets propres à la production. Ne jamais recopier les identifiants sandbox.
Les paiements restent désactivés tant que les opérateurs n'ont pas livré et
validé les paramètres de production.

## Flutter Android

Développement :

```bash
flutter run --flavor development -d emulator-5554
```

Staging :

```bash
flutter build appbundle --flavor staging --release \
  --dart-define=API_BASE_URL=https://api-staging.hotkokichaud.digital/api
```

Production :

```bash
flutter build appbundle --flavor production --release \
  --dart-define=API_BASE_URL=https://api.hotkokichaud.digital/api \
  --obfuscate --split-debug-info=build/symbols/android
```

Créer le keystore d’upload hors du dépôt, puis copier
`android/key.properties.example` vers `android/key.properties` et compléter
ses valeurs. Sauvegarder le keystore et les symboles d’obfuscation dans un
coffre sécurisé.

## Flutter iOS

La signature et les schemes iOS doivent être finalisés sur macOS avec Xcode :

- bundle production : `com.hotkoki.app` ;
- bundle staging : `com.hotkoki.app.staging` ;
- équipe Apple Developer, certificats et profils de provisioning ;
- schemes `staging` et `production` ;
- URL API injectée avec `--dart-define=API_BASE_URL=...`.

La construction App Store nécessite macOS et Xcode :

```bash
flutter build ipa --flavor production --release \
  --dart-define=API_BASE_URL=https://api.hotkokichaud.digital/api \
  --obfuscate --split-debug-info=build/symbols/ios
```

## Éléments encore externes

- domaine et hébergeur définitifs ;
- comptes Google Play Console et Apple Developer ;
- signature Android et provisioning iOS ;
- Firebase/APNs pour les notifications quand l’application est fermée ;
- identifiants MTN Production remis après validation Go-Live.
