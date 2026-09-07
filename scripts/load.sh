#!/usr/bin/env bash
# Generate ~60s of mixed traffic so the Grafana panels have something to show.
set -euo pipefail

BASE="${BASE:-http://localhost:8000}"
DURATION="${DURATION:-60}"

echo "hitting $BASE for ${DURATION}s ..."
end=$((SECONDS + DURATION))
codes=()

while [ "$SECONDS" -lt "$end" ]; do
  # create a link
  code=$(curl -s -XPOST "$BASE/api/links" \
    -H 'content-type: application/json' \
    -d "{\"target_url\":\"https://example.com/$RANDOM\"}" \
    | python3 -c 'import sys, json; print(json.load(sys.stdin)["code"])' 2>/dev/null || true)
  [ -n "$code" ] && codes+=("$code")

  # follow a known code (redirect) and one that does not exist (404)
  if [ "${#codes[@]}" -gt 0 ]; then
    curl -s -o /dev/null "$BASE/${codes[$((RANDOM % ${#codes[@]}))]}"
  fi
  curl -s -o /dev/null "$BASE/doesnotexist$RANDOM"
  curl -s -o /dev/null "$BASE/healthz"

  sleep 0.2
done

echo "done — open Grafana at http://localhost:3000"
