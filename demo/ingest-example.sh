#!/usr/bin/env bash
set -euo pipefail

TOKEN="${1:-}"
if [[ -z "$TOKEN" ]]; then
  echo "Usage: $0 <INGEST_TOKEN>"
  exit 1
fi

API="http://localhost:52773/csp/testops/api"

NOW="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

cat > /tmp/testops_ingest.json <<'JSON'
{
  "run": {
    "commitSha": "abc1234",
    "branch": "main",
    "ciProvider": "local",
    "startedAt": "__NOW__",
    "durationMs": 184000,
    "status": "failed"
  },
  "tests": [
    { "name": "auth.login.success", "status": "passed", "durationMs": 120 },
    { "name": "auth.login.invalid_password", "status": "passed", "durationMs": 95 },
    {
      "name": "orders.create.returns_201",
      "status": "failed",
      "durationMs": 450,
      "error": {
        "message": "AssertionError: expected 201, got 500",
        "stacktrace": "AssertionError: expected 201, got 500\n  at test_orders.py:41\n  at app/orders.py:120\n  at db/connection.py:88"
      }
    },
    {
      "name": "payments.charge.timeout",
      "status": "failed",
      "durationMs": 980,
      "error": {
        "message": "TimeoutError: payment gateway timed out",
        "stacktrace": "TimeoutError: timed out after 30s\n  at payments.js:233\n  at http.js:88\n  at timers.js:99"
      }
    }
  ]
}
JSON

# Replace placeholder with current time
sed -i.bak "s/__NOW__/${NOW}/g" /tmp/testops_ingest.json

echo "Ingesting sample run..."
curl -fsS -X POST "${API}/ingest/${TOKEN}/run" \
  -H "Content-Type: application/json" \
  --data-binary @/tmp/testops_ingest.json

echo
echo "Done. Open UI: http://localhost:8080"
