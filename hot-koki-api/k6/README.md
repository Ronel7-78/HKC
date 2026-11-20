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

Avant ce test, renseigner une seule fois l'IP publique de la machine de test
dans le `.env` staging. Cette exception est limitée à `APP_ENV=staging` et ne
sera jamais active en production :

```bash
# Sur la machine qui executera k6 :
curl -4 https://api.ipify.org; echo

# Reporter cette valeur dans le .env staging :
K6_TEST_IP=VOTRE_IP_PUBLIQUE

# Sur le VPS staging :
cd /var/www/hot-koki/source/hot-koki-api
sudo -u deploy php artisan optimize:clear
sudo -u deploy php artisan config:cache
```

Si le staging est deployee par GitLab, mettre aussi cette meme ligne dans la
variable `STAGING_ENV_FILE_B64`, sinon le prochain deploiement remplacera le
fichier `.env`.

```bash
cd "/home/mrroot/Bureau/HKC APP/hot-koki-api"
k6 run k6/staging-read-load.js
```

Pour un second passage un peu plus soutenu, après succès du premier :

```bash
k6 run -e LOAD_RATE=4 k6/staging-read-load.js
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
k6 run -e ATTACK_EMAIL="charge-login-$(date +%s)@hotkoki.test" \
  k6/staging-login-rate-limit.js
```

## 3. Test connecté en lecture seule

Créer un compte client de test uniquement sur staging, récupérer son jeton
après connexion, puis l'exporter seulement dans le terminal courant. Ne jamais
mettre ce jeton dans Git, dans le script ou dans une variable GitLab.

```bash
k6 run -e AUTH_TOKEN='COLLER_LE_JETON_DE_TEST_ICI' \
  k6/staging-authenticated-read.js
```

## 4. Idempotence : dix envois simultanes d'une commande

Ce test utilise un compte client **de test et deja verifie** sur staging. Il
creera exactement une commande `en_attente_paiement`, clairement marquee
`TEST K6 ... NE PAS LIVRER`, puis rejouera neuf fois la meme requete. Il ne
declenche aucun paiement CamPay.

Le catalogue staging actuel propose par defaut le produit `4` avec le
complement `7`. Ajuster les deux valeurs si ce jeu de donnees change.

```bash
read -rp 'E-mail du client de test staging : ' TEST_EMAIL
read -rsp 'Mot de passe : ' TEST_PASSWORD; echo

k6 run \
  -e TEST_EMAIL="$TEST_EMAIL" \
  -e TEST_PASSWORD="$TEST_PASSWORD" \
  -e ORDER_RUN_ID="k6-order-$(date +%s)-test" \
  -e PRODUCT_ID=4 \
  -e COMPLEMENT_ID=7 \
  k6/staging-idempotent-order.js

unset TEST_EMAIL TEST_PASSWORD
```

Le resultat attendu est strict : `orders_created = 1`, `orders_reused = 9`,
aucun echec HTTP et 100 % des checks reussis. La commande de test reste dans
staging comme trace d'audit ; elle ne doit pas etre payee ni traitee par un
vendeur.

## 5. Commandes distinctes : 25, puis 50, puis 100 clients fictifs

Cette campagne cree de vrais comptes **fictifs et verifies uniquement sur
staging**, avec un jeton par client. Elle cree une commande distincte par
client, sans aucun appel de paiement. Les commandes portent toutes la mention
`TEST K6 ... NE PAS LIVRER`.

Sur le VPS, choisir un identifiant de campagne nouveau puis creer les comptes :

```bash
cd /var/www/hot-koki/source/hot-koki-api
sudo -u deploy php artisan k6:seed-order-clients k6orders20261120a --count=100
```

Le mot de passe demande est commun aux comptes fictifs et ne sera pas affiche.
Telecharger ensuite le fichier de jetons vers Kali avec la cle SSH de staging
(ne jamais l'afficher ni le versionner) :

```bash
scp -i ~/.ssh/hkc_staging_gitlab \
  deploy@187.7.24.135:/var/www/hot-koki/source/hot-koki-api/storage/app/secure/k6-order-clients-k6orders20261120a.json \
  /tmp/k6-order-clients-k6orders20261120a.json
chmod 600 /tmp/k6-order-clients-k6orders20261120a.json
```

Depuis Kali, commencer par 25 commandes simultanees :

```bash
k6 run \
  -e TOKENS_FILE=/tmp/k6-order-clients-k6orders20261120a.json \
  -e LOAD_RUN_ID=k6orders20261120a \
  -e CLIENT_COUNT=25 \
  -e PRODUCT_ID=4 \
  -e COMPLEMENT_ID=7 \
  k6/staging-distinct-orders.js
```

Si le palier est propre, relancer avec `CLIENT_COUNT=50`, puis `CLIENT_COUNT=100`.
Le critere est strict : une reponse `201` et une commande par client, sans
erreur HTTP. A la fin, supprimer le fichier local de jetons :

```bash
shred -u /tmp/k6-order-clients-k6orders20261120a.json
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
