import http from 'k6/http';
import { check } from 'k6';
import { Trend, Rate } from 'k6/metrics';
import {
  randomIntBetween,
  uuidv4,
} from 'https://jslib.k6.io/k6-utils/1.2.0/index.js';
import { getScenario } from './scenarios.js';

// Custom metrics
const chatDuration = new Trend('chat_duration');
const chatSuccessRate = new Rate('chat_success_rate');

// Configuration
const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';
const TEST_TYPE = __ENV.TEST_TYPE || 'load'; // load | stress | spike
const TARGET_RPS = parseInt(__ENV.TARGET_RPS || '50');
const TEST_DURATION = __ENV.TEST_DURATION || '2m';
const EXPECTED_RESPONSE_TIME = parseInt(__ENV.EXPECTED_RESPONSE_TIME || '2'); // seconds
const ENABLE_DEBUG = __ENV.ENABLE_DEBUG === 'true';

// Calculate required VUs based on Little's Law
// VUs ≈ RPS × Response Time
const REQUIRED_VUS = Math.ceil(TARGET_RPS * EXPECTED_RESPONSE_TIME);

// Required parameters
const ACCOUNT_ID = __ENV.ACCOUNT_ID || '1';
const AI_AGENT_ID = __ENV.AI_AGENT_ID || '1';
const API_ACCESS_TOKEN = __ENV.API_ACCESS_TOKEN || '';

// Test options - Pure RPS Testing for AI Agent Chat
export const options = {
  scenarios: {
    ai_agent_chat_test: getScenario({
      testType: TEST_TYPE,
      targetRPS: TARGET_RPS,
      requiredVUs: REQUIRED_VUS,
      duration: TEST_DURATION,
    }),
  },
  thresholds: {
    chat_success_rate: ['rate>0.85'],
    http_req_duration: ['p(95)<30000'],
    http_req_failed: ['rate<0.15'],
  },
  summaryTrendStats: ['avg', 'min', 'med', 'max', 'p(90)', 'p(95)'],
};

// Generate chat test data
function generateChatData() {
  const questions = [
    'Halo, apa kabar?',
    "Hi, how's it going?",
    'Nama kamu siapa?',
    'Kenalin nama saya Iwan',
  ];

  return {
    question: questions[randomIntBetween(0, questions.length - 1)],
    session_id: uuidv4(),
  };
}

export default function () {
  const payload = generateChatData();

  const headers = {
    'Content-Type': 'application/json',
    Accept: 'application/json',
    'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
    'X-Requested-With': 'XMLHttpRequest',
  };

  // Add Bearer token if provided
  if (API_ACCESS_TOKEN) {
    headers['Authorization'] = `Bearer ${API_ACCESS_TOKEN}`;
  }

  const startTime = Date.now();
  const response = http.post(
    `${BASE_URL}/api/v1/accounts/${ACCOUNT_ID}/ai_agents/${AI_AGENT_ID}/chat`,
    JSON.stringify(payload),
    {
      headers: headers,
      tags: { name: 'ai_agent_chat' },
      timeout: '60s',
    }
  );
  const duration = Date.now() - startTime;

  // Track metrics
  chatDuration.add(duration);

  // Parse JSON only once
  let responseBody = null;
  try {
    responseBody = JSON.parse(response.body);
  } catch (e) {
    // Parse error handled below
  }

  // Check functional requirements using parsed data
  const isSuccessStatus = response.status === 200;
  const hasResponse =
    responseBody &&
    (responseBody.response || responseBody.message || responseBody.answer);

  const functionalSuccess = check(response, {
    'status is 200': () => isSuccessStatus,
    'has response data': () => hasResponse,
  });

  chatSuccessRate.add(functionalSuccess);

  if (!functionalSuccess && ENABLE_DEBUG) {
    console.error(
      `FAIL [${duration}ms]: ${response.status} - ${response.body.substring(0, 200)}`
    );
  }
}

export function setup() {}

export function teardown() {}
