import http from 'k6/http';
import { check } from 'k6';
import { Counter } from 'k6/metrics';
import exec from 'k6/execution';

// Test staging uniquement : chaque compte fictif soumet une commande unique.
// Aucun endpoint de paiement CamPay n'est appele.
const baseUrl = (__ENV.K6_BASE_URL || 'https://api-staging.hotkokichaud.digital/api')
  .replace(/\/$/, '');
const tokenFile = __ENV.TOKENS_FILE;
const runId = __ENV.LOAD_RUN_ID;
const requestedClients = Number(__ENV.CLIENT_COUNT || 25);
const productId = Number(__ENV.PRODUCT_ID || 4);
const complementId = Number(__ENV.COMPLEMENT_ID || 7);

if (!tokenFile || !runId) {
  throw new Error('TOKENS_FILE et LOAD_RUN_ID sont requis.');
}

const accounts = JSON.parse(open(tokenFile));
if (!Array.isArray(accounts) || accounts.length < requestedClients) {
  throw new Error('Le fichier de jetons ne contient pas assez de clients pour CLIENT_COUNT.');
}

export const ordersCreated = new Counter('orders_created');

export const options = {
  scenarios: {
    distinct_orders: {
      executor: 'shared-iterations',
      vus: requestedClients,
      iterations: requestedClients,
      maxDuration: '2m',
    },
  },
  thresholds: {
    checks: ['rate==1'],
    http_req_failed: ['rate==0'],
    orders_created: [`count==${requestedClients}`],
    http_req_duration: ['p(95)<5000'],
  },
};

export default function () {
  const account = accounts[exec.scenario.iterationInTest];
  const idempotencyKey = `${runId}-${account.index}`;
  const response = http.post(
    `${baseUrl}/commandes`,
    JSON.stringify({
      items: [{ produit_id: productId, quantite: 1, complements: [complementId] }],
      adresse_livraison: `TEST K6 ${runId} ${account.index} - NE PAS LIVRER`,
      latitude_client: 3.8667,
      longitude_client: 11.5167,
      livraison_express: false,
    }),
    {
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json',
        Authorization: `Bearer ${account.token}`,
        'Idempotency-Key': idempotencyKey,
      },
      responseCallback: http.expectedStatuses(201),
      tags: { suite: 'staging-distinct-orders', endpoint: 'commandes' },
    },
  );

  const responseBody = response.body ? response.json() : null;

  if (response.status === 201) {
    ordersCreated.add(1);
  } else {
    const message = responseBody?.message || response.error || 'sans message';
    console.error(`Commande distincte refusee: HTTP ${response.status} - ${message}`);
  }

  check(response, {
    'commande distincte: HTTP 201': (result) => result.status === 201,
    'commande distincte: code public present': () => Boolean(responseBody?.commande?.code_commande),
  });
}
