#!/usr/bin/env bash
set -euo pipefail

TOKEN="${1:-}"
if [[ -z "$TOKEN" ]]; then
  echo "Usage: $0 <INGEST_TOKEN>"
  exit 1
fi

API="http://localhost:52773/csp/testops/api"

guess_now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

post_run() {
  local sha="$1"
  local status="$2"
  local now
  now="$(guess_now)"

  cat > /tmp/testops_ingest.json <<JSON
{
  "run": {
    "commitSha": "$sha",
    "branch": "main",
    "ciProvider": "local",
    "startedAt": "$now",
    "durationMs": 190000,
    "status": "$status"
  },
  "tests": [
    { "name": "auth.login.success", "status": "passed", "durationMs": 120 },
    { "name": "auth.login.invalid_password", "status": "passed", "durationMs": 95 },
    { "name": "orders.create.returns_201", "status": "${status}", "durationMs": 450,
      "error": {
        "message": "AssertionError: expected 201, got 500",
        "stacktrace": "AssertionError: expected 201, got 500\n  at test_orders.py:41\n  at app/orders.py:120\n  at db/connection.py:88"
      }
    },
    { "name": "payments.charge.timeout", "status": "failed", "durationMs": 980,
      "error": {
        "message": "TimeoutError: payment gateway timed out",
        "stacktrace": "TimeoutError: timed out after 30s\n  at payments.js:233\n  at http.js:88\n  at timers.js:99"
      }
    },
    { "name": "search.relevance.rank", "status": "passed", "durationMs": 210 },
    { "name": "reports.export.csv", "status": "passed", "durationMs": 330 }
  ]
}
JSON

  echo "Ingesting run sha=$sha status=$status"
  curl -fsS -X POST "${API}/ingest/${TOKEN}/run" -H "Content-Type: application/json" --data-binary @/tmp/testops_ingest.json > /dev/null
}

post_run "abc1001" "failed"
sleep 1
post_run "abc1002" "passed"
sleep 1
post_run "abc1003" "failed"

echo "Done. Open UI: http://localhost:8080"
