# Tests de charge k6 — staging

Ces scripts ciblent exclusivement l'API staging. Ils n'utilisent aucun secret
du dépôt et n'initient ni commande ni paiement.

## Préparer la machine de test

Installer k6 selon la documentation officielle :

```bash
sudo gpg -k
curl -fsSL https://dl.k6.io/key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/k6-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
sudo apt update
sudo apt install -y k6
k6 version
```

## 1. Test public — à lancer en premier

Il lit l'accueil, le catalogue et les avis. La charge par défaut représente
6 requêtes HTTP par seconde au palier principal.

```bash
cd "/home/mrroot/Bureau/HKC APP/hot-koki-api"
k6 run k6/staging-read-load.js
```

Pour un second passage un peu plus soutenu, après succès du premier :

```bash
K6_RATE=4 k6 run k6/staging-read-load.js
```

## 2. Anti-bruteforce de connexion

Ce test ne tente aucun compte existant. Il envoie six mots de passe invalides
pour le même identifiant fictif : les cinq premières réponses doivent être
`401`, puis la sixième doit être `429 Trop de tentatives`.

```bash
k6 run k6/staging-login-rate-limit.js
```

Pour le relancer immédiatement, changer l'adresse fictive (la limite par
adresse dure une minute) :

```bash
K6_ATTACK_EMAIL="charge-login-$(date +%s)@hotkoki.test" \
  k6 run k6/staging-login-rate-limit.js
```

## 3. Test connecté en lecture seule

Créer un compte client de test uniquement sur staging, récupérer son jeton
après connexion, puis l'exporter seulement dans le terminal courant. Ne jamais
mettre ce jeton dans Git, dans le script ou dans une variable GitLab.

```bash
export K6_AUTH_TOKEN='COLLER_LE_JETON_DE_TEST_ICI'
k6 run k6/staging-authenticated-read.js
unset K6_AUTH_TOKEN
```

## Critères de succès avant production

- `http_req_failed` inférieur à 1 % ;
- 95 % des requêtes sous 1,5 seconde ;
- 99 % des requêtes sous 3 secondes ;
- aucune erreur 5xx dans les logs Laravel et Nginx ;
- aucune alerte de saturation MySQL, Redis, PHP-FPM ou disque.

## Consultation des logs staging

Les fichiers Laravel sont quotidiens et restent 14 jours :

```bash
ssh root@187.7.24.135
cd /var/www/hot-koki/source/hot-koki-api
tail -f storage/logs/laravel-$(date +%F).log
```

Les accès et erreurs Nginx se consultent avec :

```bash
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

Pour production, le principe est identique, avec 30 jours de rétention Laravel.
