import http from 'k6/http';
import { check } from 'k6';
import { Trend, Rate } from 'k6/metrics';
import {
  randomString,
  randomIntBetween,
} from 'https://jslib.k6.io/k6-utils/1.2.0/index.js';
import { getScenario } from './scenarios.js';

const registrationDuration = new Trend('registration_duration');
const registrationSuccessRate = new Rate('registration_success_rate');

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';
const TEST_TYPE = __ENV.TEST_TYPE || 'load'; // load | stress | spike
const TARGET_RPS = parseInt(__ENV.TARGET_RPS || '50');
const TEST_DURATION = __ENV.TEST_DURATION || '2m';
const EXPECTED_RESPONSE_TIME = parseInt(__ENV.EXPECTED_RESPONSE_TIME || '2'); // seconds
const ENABLE_DEBUG = __ENV.ENABLE_DEBUG === 'true';

// Calculate required VUs based on Little's Law
// VUs ≈ RPS × Response Time
const REQUIRED_VUS = Math.ceil(TARGET_RPS * EXPECTED_RESPONSE_TIME);

export const options = {
  scenarios: {
    registration_test: getScenario({
      testType: TEST_TYPE,
      targetRPS: TARGET_RPS,
      requiredVUs: REQUIRED_VUS,
      duration: TEST_DURATION,
    }),
  },
  thresholds: {
    registration_success_rate: ['rate>0.85'],
    http_req_duration: ['p(95)<30000'],
    http_req_failed: ['rate<0.15'],
  },
  summaryTrendStats: ['avg', 'min', 'med', 'max', 'p(90)', 'p(95)'],
};

function generateTestData() {
  const timestamp = Date.now();
  const random = randomString(8);

  return {
    account_name: `TestCompany_${random}`,
    email: `test_${timestamp}_${random}@example.com`,
    password: `Password123!${random}`,
    user_full_name: `Test User ${random}`,
    phoneNumber: `+628${randomIntBetween(100000000, 999999999)}`,
    locale: 'id',
    h_captcha_client_response: 'bypass-captcha-for-testing',
  };
}

export default function () {
  const payload = generateTestData();

  const response = http.post(
    `${BASE_URL}/api/v1/accounts`,
    JSON.stringify(payload),
    {
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
        'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
        'X-Requested-With': 'XMLHttpRequest',
      },
      tags: { name: 'registration' },
      timeout: '60s',
    }
  );

  registrationDuration.add(response.timings.duration);

  const functionalSuccess = check(response, {
    'status is 201': r => r.status === 201,
  });

  registrationSuccessRate.add(functionalSuccess);

  if (!functionalSuccess && ENABLE_DEBUG) {
    console.error(`FAIL: ${response.status}`);
  }
}

export function setup() {}

export function teardown() {}
