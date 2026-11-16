#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${SAGI_ENV_FILE:-/etc/sagi-pool-sync.env}"
NGINX_FILE="${SAGI_NGINX_FILE:-/etc/nginx/sites-available/sagi-pool.conf}"
FAILED=0

ok(){ printf '✓ %s\n' "$1"; }
fail(){ printf '✗ %s\n' "$1" >&2; FAILED=1; }
value(){
  local key="$1"
  awk -F= -v k="$key" '$1==k{sub(/^[^=]*=/,"");print;exit}' "$ENV_FILE" 2>/dev/null || true
}

echo "SAGI POOL V1.0 production verification"
echo "-------------------------------------"

if command -v node >/dev/null 2>&1; then
  MAJOR="$(node -p "process.versions.node.split('.')[0]")"
  if [ "$MAJOR" -ge 20 ]; then ok "Node.js $(node -v)"; else fail "Node.js must be 20+"; fi
else
  fail "Node.js is not installed"
fi

if [ -f "$ENV_FILE" ]; then
  ok "Environment file exists"
else
  fail "Environment file missing: $ENV_FILE"
fi

if [ -f "$ENV_FILE" ]; then
  REQUIRE_LICENSE="$(value SAGI_REQUIRE_LICENSE)"
  [ "$REQUIRE_LICENSE" = "1" ] && ok "Commercial license mode enabled" || fail "SAGI_REQUIRE_LICENSE must be 1"

  ADMIN_TOKEN="$(value SAGI_ADMIN_TOKEN)"
  if [ "${#ADMIN_TOKEN}" -ge 24 ] && [ "$ADMIN_TOKEN" != "CHANGE_TO_A_LONG_RANDOM_ADMIN_SECRET" ]; then
    ok "Admin secret is non-default and sufficiently long"
  else
    fail "Admin secret is missing/default/too short"
  fi

  ORIGIN="$(value SAGI_ALLOW_ORIGIN)"
  if [[ "$ORIGIN" == https://* ]] && [[ "$ORIGIN" != *"example.com"* ]]; then
    ok "CORS origin uses production HTTPS"
  else
    fail "SAGI_ALLOW_ORIGIN must be a real HTTPS production origin"
  fi

  DATA_FILE="$(value SAGI_DATA_FILE)"
  BACKUP_DIR="$(value SAGI_BACKUP_DIR)"
  if [ -n "$DATA_FILE" ] && [ -d "$(dirname "$DATA_FILE")" ] && [ -w "$(dirname "$DATA_FILE")" ]; then
    ok "Data directory writable"
  else
    fail "Data directory missing or not writable"
  fi
  if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ] && [ -w "$BACKUP_DIR" ]; then
    ok "Backup directory writable"
  else
    fail "Backup directory missing or not writable"
  fi
fi

if [ -f "$NGINX_FILE" ]; then
  if grep -q 'pool\.example\.com' "$NGINX_FILE"; then
    fail "Nginx still contains pool.example.com placeholder"
  else
    ok "Nginx production hostname configured"
  fi
else
  fail "Nginx SAGI config missing"
fi

if command -v nginx >/dev/null 2>&1 && nginx -t >/dev/null 2>&1; then
  ok "Nginx configuration valid"
else
  fail "Nginx configuration validation failed"
fi

if command -v systemctl >/dev/null 2>&1; then
  systemctl is-enabled sagi-pool-sync.service >/dev/null 2>&1 && ok "Sync service enabled" || fail "Sync service not enabled"
  systemctl is-active sagi-pool-sync.service >/dev/null 2>&1 && ok "Sync service active" || fail "Sync service not active"
  systemctl is-enabled sagi-pool-backup.timer >/dev/null 2>&1 && ok "Daily backup timer enabled" || fail "Daily backup timer not enabled"
  systemctl is-active sagi-pool-backup.timer >/dev/null 2>&1 && ok "Daily backup timer active" || fail "Daily backup timer not active"
fi

if [ -f /etc/nginx/ssl/fullchain.pem ] && [ -f /etc/nginx/ssl/privkey.pem ]; then
  ok "TLS certificate files present"
else
  fail "TLS certificate files missing"
fi

if [ -f "$ENV_FILE" ]; then
  ORIGIN="$(value SAGI_ALLOW_ORIGIN)"
  if command -v curl >/dev/null 2>&1 && [[ "$ORIGIN" == https://* ]]; then
    HEALTH="$(curl -fsS --max-time 8 "$ORIGIN/health" 2>/dev/null || true)"
    if printf '%s' "$HEALTH" | grep -q '"ok":true'; then
      ok "Public HTTPS /health reachable"
    else
      fail "Public HTTPS /health check failed"
    fi
  fi
fi

echo "-------------------------------------"
if [ "$FAILED" -ne 0 ]; then
  echo "SAGI production verification: FAILED" >&2
  exit 1
fi
echo "SAGI production verification: PASSED"
