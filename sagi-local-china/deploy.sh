#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: Docker is required."
  exit 1
fi

if [ ! -f .env ]; then
  cp .env.example .env
  echo "Created .env from .env.example."
  echo "Edit SAGI_SECRET before production deployment."
  exit 2
fi

if grep -q '^SAGI_SECRET=change-this-to-a-long-random-secret$' .env; then
  echo "ERROR: SAGI_SECRET is still the default value."
  exit 3
fi

docker compose up -d --build

echo "Waiting for SAGI AI LOCAL CHINA..."
for i in $(seq 1 30); do
  if curl -fsS http://127.0.0.1:8080/health >/tmp/sagi-local-china-health.json 2>/dev/null; then
    cat /tmp/sagi-local-china-health.json
    echo
    echo "SAGI AI LOCAL CHINA is running on port 8080."
    exit 0
  fi
  sleep 2
done

echo "ERROR: health check failed."
docker compose logs --tail=80
exit 4
