# RPS Performance Test

Script K6 untuk menguji performa endpoint dengan pure RPS (Requests Per Second) testing.

## Available Test Scripts

| Script                      | Description               | Use Case                     |
| --------------------------- | ------------------------- | ---------------------------- |
| `registration_rps_test.js`  | Registration RPS testing  | User registration throughput |
| `ai_agent_chat_rps_test.js` | AI Agent Chat RPS testing | LLM chat endpoint throughput |

## Prerequisites

```bash
# Install k6
brew install k6              # macOS
choco install k6            # Windows
sudo apt-get install k6     # Ubuntu/Debian
```

## Configuration

Set environment variables sebelum menjalankan test:

```bash
export BASE_URL="http://localhost:3000"  # URL target server
```

## Cara Menjalankan

### 1. Registration RPS Test

```bash
# Default: 50 RPS selama 2 menit
k6 run k6/registration_rps_test.js

# Custom RPS dan durasi
TARGET_RPS=100 TEST_DURATION=5m k6 run k6/registration_rps_test.js

# Adjust untuk slow server
TARGET_RPS=20 EXPECTED_RESPONSE_TIME=25 TEST_DURATION=3m k6 run k6/registration_rps_test.js
```

### 2. AI Agent Chat RPS Test

```bash
# Setup required parameters
export ACCOUNT_ID="1"
export AI_AGENT_ID="1"
export API_ACCESS_TOKEN="your_bearer_token_here"

# Run test (default: 50 RPS, 5 menit)
k6 run k6/ai_agent_chat_rps_test.js

# Custom RPS
TARGET_RPS=100 TEST_DURATION=10m k6 run k6/ai_agent_chat_rps_test.js
```

**Required Parameters:**

- `ACCOUNT_ID`: Account ID untuk AI Agent
- `AI_AGENT_ID`: ID AI Agent yang akan di-test
- `API_ACCESS_TOKEN`: Bearer token untuk authentication (required)

**Authentication:** Token dikirim dengan header `Authorization: Bearer <token>`

### 3. Run dengan Output ke InfluxDB

```bash
k6 run --out influxdb=http://localhost:8086/k6 k6/registration_rps_test.js
```

### 4. Run dengan JSON Output

```bash
k6 run --out json=results.json k6/registration_rps_test.js
```

## Test Scenarios

### Registration RPS Test

Constant arrival rate testing untuk endpoint registrasi:

- **Target**: X requests per second (default: 50 RPS)
- **Duration**: Y menit (default: 2 menit)
- **VUs**: Auto-scaled berdasarkan `TARGET_RPS × EXPECTED_RESPONSE_TIME`
- **Timeout**: 60 detik

**Use case**: Mengukur throughput maksimal endpoint registration

### AI Agent Chat RPS Test

RPS testing untuk AI Agent chat endpoint:

- **Target**: X requests per second (default: 50 RPS)
- **Duration**: Y menit (default: 5 menit)
- **VUs**: Auto-scaled (lebih tinggi untuk handle LLM latency)
- **Timeout**: 60 detik (lebih lama untuk LLM response)

**Use case**: Mengukur throughput chat endpoint dengan LLM backend

## Environment Variables

### Common Variables

| Variable                 | Default                 | Description                       |
| ------------------------ | ----------------------- | --------------------------------- |
| `BASE_URL`               | `http://localhost:3000` | Target server URL                 |
| `TARGET_RPS`             | `50`                    | Target requests per second        |
| `TEST_DURATION`          | `2m`                    | Test duration (e.g., 2m, 5m, 1h)  |
| `EXPECTED_RESPONSE_TIME` | `20`                    | Expected response time in seconds |
| `ENABLE_DEBUG`           | `false`                 | Enable debug logging              |

### AI Agent Chat Variables

| Variable           | Default | Description                           |
| ------------------ | ------- | ------------------------------------- |
| `ACCOUNT_ID`       | `1`     | Account ID untuk AI Agent             |
| `AI_AGENT_ID`      | `1`     | AI Agent ID yang akan di-test         |
| `API_ACCESS_TOKEN` | -       | API token untuk Bearer authentication |

**Authentication Format:**
Script menggunakan standar Bearer token format:

```
Authorization: Bearer <API_ACCESS_TOKEN>
```

## Thresholds

### Registration RPS Test

Test akan FAIL jika:

- Functional success rate < 85%
- HTTP failure rate > 15%
- Response time P95 > 30 detik

### AI Agent Chat RPS Test

Test akan FAIL jika:

- Functional success rate < 85%
- HTTP failure rate > 15%
- Response time P95 > 30 detik

## Metrics yang Di-track

### Registration Test

1. **registration_duration**: Response time registrasi (ms)
2. **registration_success_rate**: Persentase registrasi sukses
3. **http_req_duration**: Response time HTTP requests
4. **http_req_failed**: Failed requests rate

### AI Agent Chat Test

1. **chat_duration**: Response time chat (ms)
2. **chat_success_rate**: Persentase chat sukses
3. **http_req_duration**: Response time HTTP requests
4. **http_req_failed**: Failed requests rate

## Customization

### RPS Test - Configuration

Environment variables untuk RPS test:

```bash
export TARGET_RPS=100        # Target requests per second
export TEST_DURATION=5m      # Test duration
export EXPECTED_RESPONSE_TIME=20  # Expected response time in seconds
export BASE_URL=http://...   # Target server URL
```

**Contoh scenarios:**

```bash
# Test 50 RPS selama 3 menit
TARGET_RPS=50 TEST_DURATION=3m k6 run k6/registration_rps_test.js

# Test 100 RPS selama 5 menit
TARGET_RPS=100 TEST_DURATION=5m k6 run k6/registration_rps_test.js

# Stress test - find breaking point
TARGET_RPS=200 EXPECTED_RESPONSE_TIME=30 TEST_DURATION=2m k6 run k6/registration_rps_test.js
```

### Ubah Thresholds

Edit file test, ubah bagian `thresholds`:

```javascript
thresholds: {
  registration_success_rate: ['rate>0.90'],  // 90% success
  http_req_duration: ['p(95)<20000'],        // 20 detik
  http_req_failed: ['rate<0.10'],            // 10% failure
},
```

## Troubleshooting

### Error: "Insufficient VUs"

Jika muncul warning:

```
Insufficient VUs, reached X active VUs and cannot initialize more
```

**Solusi:**

```bash
# Naikkan expected response time
EXPECTED_RESPONSE_TIME=30 TARGET_RPS=50 k6 run k6/registration_rps_test.js

# Atau turunkan target RPS
TARGET_RPS=30 k6 run k6/registration_rps_test.js
```

### Error: "Rack::Attack [Blocked]"

Jika request di-block oleh rate limiter:

1. Whitelist IP testing di server
2. Atau disable Rack::Attack untuk testing:
   ```bash
   export ENABLE_RACK_ATTACK=false
   ```

### Error: "Authentication Failed"

Untuk AI Agent Chat test, pastikan token valid:

```bash
export API_ACCESS_TOKEN="your_token_here"
```

Token akan dikirim dengan format Bearer:

```
Authorization: Bearer <your_token_here>
```

## Contoh Output

```
╔══════════════════════════════════════════════════════════╗
║           PURE RPS REGISTRATION TEST                     ║
╚══════════════════════════════════════════════════════════╝

Target RPS:        50 req/s
Test Duration:     2m
Expected Response: 20s
Required VUs:      1000
Max VUs:           1500

Starting test...

█ THRESHOLDS
    http_req_duration
    ✓ 'p(95)<30000' p(95)=6.8s

    http_req_failed
    ✓ 'rate<0.15' rate=0.00%

    registration_success_rate
    ✓ 'rate>0.85' rate=100.00%

█ TOTAL RESULTS
    checks_total.......: 12005   94.685589/s
    checks_succeeded...: 100.00% 12005 out of 12005

    CUSTOM
    registration_duration..........: avg=2.85s min=299.96ms med=1.84s max=7.17s p(90)=6.69s p(95)=6.8s
    registration_success_rate......: 100.00% 2401 out of 2401

    HTTP
    http_req_duration..............: avg=2.85s min=299.96ms med=1.84s max=7.17s p(90)=6.69s p(95)=6.8s
    http_req_failed................: 0.00%   0 out of 2401
    http_reqs......................: 2401    18.937118/s

    EXECUTION
    iteration_duration.............: avg=2.87s min=300.91ms med=1.84s max=7.17s p(90)=6.69s p(95)=6.8s
    iterations.....................: 2401    18.937118/s
    vus............................: 22      min=6            max=137
    vus_max........................: 200     min=200          max=200

╔══════════════════════════════════════════════════════════╗
║           RPS TEST CONFIGURATION                         ║
╚══════════════════════════════════════════════════════════╝

Test Parameters:
  • Base URL:           https://staging.example.com
  • Target RPS:         50 requests/second
  • Test Duration:      2.1 minutes
  • Expected Response:  20 seconds
  • Required VUs:       1000
  • Max VUs Allocated:  1500

Look at the k6 summary above for results:
  ✓ http_reqs: Total requests sent
  ✓ http_req_duration: Response time stats
  ✓ dropped_iterations: Requests that could not be sent
  ✓ registration_success_rate: Functional success %
```

## Tips Optimasi

1. **Distributed Testing**: Gunakan k6 cloud atau k6-operator untuk Kubernetes
2. **Monitoring**: Integrasi dengan Grafana + InfluxDB untuk real-time monitoring
3. **Test Data**: Gunakan CSV untuk test data yang lebih kompleks
4. **Scenarios**: Pisahkan test scenarios untuk load, stress, dan spike testing

## Referensi

- [k6 Documentation](https://k6.io/docs/)
- [k6 Constant Arrival Rate](https://k6.io/docs/using-k6/scenarios/executors/constant-arrival-rate/)
- [Performance Testing Best Practices](https://k6.io/docs/testing-guides/running-large-tests/)
