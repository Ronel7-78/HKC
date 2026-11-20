import http from 'k6/http';
import { check, sleep } from 'k6';

// Test de securite sans compte reel : le meme identifiant inexistant est
// volontairement utilise six fois. Aucune commande, aucun paiement et aucun
// email ne sont crees.
const baseUrl = (__ENV.K6_BASE_URL || 'https://api-staging.hotkokichaud.digital/api')
  .replace(/\/$/, '');
const email = __ENV.K6_ATTACK_EMAIL || 'charge-login-invalide@hotkoki.test';

export const options = {
  vus: 1,
  iterations: 1,
  thresholds: {
    checks: ['rate==1'],
    http_req_failed: ['rate==0'],
  },
};

const params = {
  headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
  // Les 401 et 429 sont le comportement attendu de ce test de securite ;
  // ils ne doivent donc pas etre comptes comme une panne HTTP par k6.
  responseCallback: http.expectedStatuses(401, 429),
  tags: { suite: 'staging-login-rate-limit' },
};

export default function () {
  const payload = JSON.stringify({
    email,
    password: 'mot-de-passe-volontairement-invalide',
    conditions_acceptees: true,
  });

  for (let attempt = 1; attempt <= 6; attempt += 1) {
    const response = http.post(`${baseUrl}/login`, payload, params);
    const expectedStatus = attempt <= 5 ? 401 : 429;

    check(response, {
      [`tentative ${attempt}: HTTP ${expectedStatus}`]: (result) => result.status === expectedStatus,
      'reponse JSON securisee': (result) => {
        const body = result.json();
        return body && typeof body.message === 'string' && !body.password && !body.token;
      },
    });
    sleep(0.2);
  }
}
