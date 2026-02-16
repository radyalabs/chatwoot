// k6/scenarios.js - Reusable scenario configurations for load testing
// Usage: import { getScenario } from './scenarios.js';

/**
 * Calculate required VUs based on Little's Law
 * VUs ≈ RPS × Response Time
 * @param {number} targetRPS - Target requests per second
 * @param {number} expectedResponseTime - Expected response time in seconds
 * @returns {number} Required VUs
 */
export function calculateRequiredVUs(targetRPS, expectedResponseTime) {
  return Math.ceil(targetRPS * expectedResponseTime);
}

/**
 * Get scenario configuration for load, stress, or spike testing
 * @param {Object} config - Configuration object
 * @param {string} config.testType - Test type: 'load' | 'stress' | 'spike'
 * @param {number} config.targetRPS - Target requests per second
 * @param {number} config.requiredVUs - Required virtual users
 * @param {string} config.duration - Test duration (e.g., '2m', '5m')
 * @returns {Object} k6 scenario configuration
 */
export function getScenario({
  testType,
  targetRPS,
  requiredVUs,
  duration = '2m',
}) {
  const baseConfig = {
    timeUnit: '1s',
    preAllocatedVUs: requiredVUs,
    gracefulStop: '30s',
  };

  const scenarios = {
    load: {
      executor: 'constant-arrival-rate',
      rate: targetRPS,
      duration: duration,
      maxVUs: requiredVUs * 2,
    },
    stress: {
      executor: 'ramping-arrival-rate',
      startRate: targetRPS,
      stages: [
        { target: targetRPS * 2, duration: '2m' },
        { target: targetRPS * 3, duration: '2m' },
        { target: targetRPS * 4, duration: '2m' },
      ],
      maxVUs: requiredVUs * 5,
    },
    spike: {
      executor: 'ramping-arrival-rate',
      startRate: targetRPS,
      stages: [
        { target: targetRPS * 5, duration: '30s' },
        { target: targetRPS, duration: '1m' },
      ],
      maxVUs: requiredVUs * 6,
    },
  };

  const testTypeConfig = scenarios[testType];

  if (!testTypeConfig) {
    throw new Error(
      `Unknown test type: ${testType}. Must be one of: load, stress, spike`
    );
  }

  return {
    ...baseConfig,
    ...testTypeConfig,
  };
}

/**
 * Get standard threshold configurations
 * @param {string} metricName - Base metric name (e.g., 'chat_success_rate', 'registration_success_rate')
 * @param {Object} options - Optional overrides
 * @returns {Object} k6 thresholds configuration
 */
export function getStandardThresholds(metricName, options = {}) {
  const {
    successRateThreshold = 0.85,
    p95ResponseTime = 30000,
    maxErrorRate = 0.15,
  } = options;

  return {
    [metricName]: [`rate>${successRateThreshold}`],
    http_req_duration: [`p(95)<${p95ResponseTime}`],
    http_req_failed: [`rate<${maxErrorRate}`],
  };
}

/**
 * Get standard k6 options with scenarios
 * @param {Object} config - Configuration object
 * @param {string} config.scenarioName - Unique scenario name
 * @param {string} config.testType - Test type: 'load' | 'stress' | 'spike'
 * @param {number} config.targetRPS - Target requests per second
 * @param {number} config.expectedResponseTime - Expected response time in seconds
 * @param {string} config.duration - Test duration
 * @param {string} metricName - Metric name for thresholds
 * @param {Object} thresholdOptions - Optional threshold overrides
 * @returns {Object} Complete k6 options object
 */
export function getStandardOptions({
  scenarioName,
  testType,
  targetRPS,
  expectedResponseTime,
  duration = '2m',
  metricName,
  thresholdOptions = {},
}) {
  const requiredVUs = calculateRequiredVUs(targetRPS, expectedResponseTime);

  return {
    scenarios: {
      [scenarioName]: getScenario({
        testType,
        targetRPS,
        requiredVUs,
        duration,
      }),
    },
    thresholds: getStandardThresholds(metricName, thresholdOptions),
    summaryTrendStats: ['avg', 'min', 'med', 'max', 'p(90)', 'p(95)'],
  };
}
