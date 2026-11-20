import http from 'k6/http';
import { check } from 'k6';
import { Counter } from 'k6/metrics';

// Test d'idempotence uniquement sur staging. Dix requetes identiques sont
// envoyees au meme instant avec une meme cle : une seule commande doit etre
// creee et les neuf autres doivent reutiliser cette commande. Aucun paiement
// CamPay n'est appele par ce script.
const baseUrl = (__ENV.K6_BASE_URL || 'https://api-staging.hotkokichaud.digital/api')
  .replace(/\/$/, '');
const email = __ENV.TEST_EMAIL;
const password = __ENV.TEST_PASSWORD;
const runId = __ENV.ORDER_RUN_ID;
const productId = Number(__ENV.PRODUCT_ID || 4);
const complementId = Number(__ENV.COMPLEMENT_ID || 7);

if (!email || !password || !runId) {
  throw new Error('TEST_EMAIL, TEST_PASSWORD et ORDER_RUN_ID sont requis.');
}

if (!/^[A-Za-z0-9_-]{16,128}$/.test(runId)) {
  throw new Error('ORDER_RUN_ID doit contenir entre 16 et 128 caracteres alphanumeriques, tirets ou underscores.');
}

export const ordersCreated = new Counter('orders_created');
export const ordersReused = new Counter('orders_reused');

export const options = {
  scenarios: {
    concurrent_idempotent_order: {
      executor: 'shared-iterations',
      vus: 10,
      iterations: 10,
      maxDuration: '30s',
    },
  },
  thresholds: {
    checks: ['rate==1'],
    http_req_failed: ['rate==0'],
    orders_created: ['count==1'],
    orders_reused: ['count==9'],
  },
};

export function setup() {
  const response = http.post(
    `${baseUrl}/login`,
    JSON.stringify({ email, password, conditions_acceptees: true }),
    {
      headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
      responseCallback: http.expectedStatuses(200),
      tags: { suite: 'staging-idempotent-order', endpoint: 'login' },
    },
  );

  check(response, { 'connexion test: HTTP 200': (result) => result.status === 200 });
  const token = response.json('token');
  if (!token) {
    throw new Error('Connexion du compte client de test impossible.');
  }

  return { token };
}

export default function (data) {
  const response = http.post(
    `${baseUrl}/commandes`,
    JSON.stringify({
      items: [{ produit_id: productId, quantite: 1, complements: [complementId] }],
      adresse_livraison: `TEST K6 ${runId} - NE PAS LIVRER`,
      latitude_client: 3.8667,
      longitude_client: 11.5167,
      livraison_express: false,
    }),
    {
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json',
        Authorization: `Bearer ${data.token}`,
        'Idempotency-Key': runId,
      },
      responseCallback: http.expectedStatuses(200, 201),
      tags: { suite: 'staging-idempotent-order', endpoint: 'commandes' },
    },
  );

  if (response.status === 201) {
    ordersCreated.add(1);
  }
  if (response.status === 200) {
    ordersReused.add(1);
  }

  if (response.status !== 200 && response.status !== 201) {
    // Uniquement le statut et le message API, jamais les en-tetes ni le token.
    console.error(`Commande idempotente refusee: HTTP ${response.status} - ${response.json('message') || 'sans message'}`);
  }

  check(response, {
    'commande: HTTP 200 ou 201': (result) => result.status === 200 || result.status === 201,
    'commande: code public present': (result) => Boolean(result.json('commande.code_commande')),
  });
}
