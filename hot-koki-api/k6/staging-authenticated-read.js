import http from 'k6/http';
import { check, sleep } from 'k6';

// Ne lancer ce scénario qu'avec un jeton de compte client de test staging.
// Le script effectue uniquement des GET et ne peut pas créer de paiement.
const baseUrl = (__ENV.K6_BASE_URL || 'https://api-staging.hotkokichaud.digital/api')
  .replace(/\/$/, '');
const token = __ENV.K6_AUTH_TOKEN;

if (!token) {
  throw new Error('K6_AUTH_TOKEN est requis et doit appartenir à un compte de test staging.');
}

export const options = {
  vus: Number(__ENV.K6_VUS || 3),
  duration: __ENV.K6_DURATION || '90s',
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<1500', 'p(99)<3000'],
    checks: ['rate>0.99'],
  },
};

const params = {
  headers: {
    Accept: 'application/json',
    Authorization: `Bearer ${token}`,
  },
  tags: { suite: 'staging-authenticated-read' },
};

export default function () {
  const responses = http.batch([
    ['GET', `${baseUrl}/me`, null, { ...params, tags: { endpoint: 'me' } }],
    ['GET', `${baseUrl}/client/catalogue?mode=standard`, null, { ...params, tags: { endpoint: 'client-catalogue' } }],
    ['GET', `${baseUrl}/commandes`, null, { ...params, tags: { endpoint: 'commandes' } }],
  ]);

  check(responses[0], { 'profil: HTTP 200': (response) => response.status === 200 });
  check(responses[1], { 'catalogue client: HTTP 200': (response) => response.status === 200 });
  check(responses[2], { 'commandes: HTTP 200': (response) => response.status === 200 });
  sleep(0.5);
}
