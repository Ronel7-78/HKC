import http from 'k6/http';
import { check, sleep } from 'k6';

// Ce scénario ne fait que lire des données publiques : aucune commande,
// aucun paiement, aucun e-mail et aucune donnée de test ne sont créés.
const baseUrl = (__ENV.K6_BASE_URL || 'https://api-staging.hotkokichaud.digital/api')
  .replace(/\/$/, '');
const rate = Number(__ENV.LOAD_RATE || 2);

export const options = {
  scenarios: {
    catalogue_public: {
      executor: 'ramping-arrival-rate',
      startRate: 1,
      timeUnit: '1s',
      preAllocatedVUs: 10,
      maxVUs: 30,
      stages: [
        { target: rate, duration: '30s' },
        { target: rate, duration: '2m' },
        { target: 1, duration: '30s' },
      ],
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<1500', 'p(99)<3000'],
    checks: ['rate>0.99'],
  },
};

const params = {
  headers: { Accept: 'application/json' },
  tags: { suite: 'staging-read-load' },
};

export default function () {
  const responses = http.batch([
    ['GET', `${baseUrl}/accueil`, null, { ...params, tags: { endpoint: 'accueil' } }],
    ['GET', `${baseUrl}/catalogue`, null, { ...params, tags: { endpoint: 'catalogue' } }],
    ['GET', `${baseUrl}/avis-publics?par_page=10`, null, { ...params, tags: { endpoint: 'avis-publics' } }],
  ]);

  check(responses[0], { 'accueil: HTTP 200': (response) => response.status === 200 });
  check(responses[1], { 'catalogue: HTTP 200': (response) => response.status === 200 });
  check(responses[2], { 'avis: HTTP 200': (response) => response.status === 200 });
  sleep(0.2);
}
