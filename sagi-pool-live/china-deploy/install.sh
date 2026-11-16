#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
APP_ROOT="$(cd "$HERE/.." && pwd)"

if ! command -v node >/dev/null 2>&1; then
  echo "ERROR: Node.js 20+ is required."
  exit 1
fi
if ! command -v nginx >/dev/null 2>&1; then
  echo "ERROR: nginx is required."
  exit 1
fi

NODE_MAJOR="$(node -p "process.versions.node.split('.')[0]")"
if [ "$NODE_MAJOR" -lt 20 ]; then
  echo "ERROR: Node.js 20+ is required."
  exit 1
fi

sudo mkdir -p /var/www/sagi-pool-live /opt/sagi-pool-sync /etc/nginx/ssl

sudo cp "$APP_ROOT/index.html" /var/www/sagi-pool-live/
sudo cp "$APP_ROOT/club.html" /var/www/sagi-pool-live/
sudo cp "$APP_ROOT/live.html" /var/www/sagi-pool-live/
sudo cp "$APP_ROOT/admin.html" /var/www/sagi-pool-live/
sudo cp "$APP_ROOT/manifest.webmanifest" /var/www/sagi-pool-live/
sudo cp "$APP_ROOT/icon.svg" /var/www/sagi-pool-live/
sudo cp "$APP_ROOT/sw.js" /var/www/sagi-pool-live/

sudo cp "$APP_ROOT/china-sync/server.mjs" /opt/sagi-pool-sync/
sudo cp "$APP_ROOT/china-sync/package.json" /opt/sagi-pool-sync/

if [ ! -f /etc/sagi-pool-sync.env ]; then
  sudo cp "$HERE/sagi-pool-sync.env.example" /etc/sagi-pool-sync.env
  echo "Created /etc/sagi-pool-sync.env — edit secrets before starting."
fi

sudo cp "$HERE/sagi-pool-sync.service" /etc/systemd/system/sagi-pool-sync.service
sudo cp "$HERE/nginx-sagi-pool.conf" /etc/nginx/sites-available/sagi-pool.conf
sudo ln -sfn /etc/nginx/sites-available/sagi-pool.conf /etc/nginx/sites-enabled/sagi-pool.conf

sudo chown -R www-data:www-data /var/www/sagi-pool-live /opt/sagi-pool-sync
sudo systemctl daemon-reload

echo
echo "FILES INSTALLED."
echo "Next:"
echo "1) Edit /etc/sagi-pool-sync.env"
echo "2) Replace pool.example.com in /etc/nginx/sites-available/sagi-pool.conf"
echo "3) Put TLS certs in /etc/nginx/ssl/fullchain.pem and privkey.pem"
echo "4) sudo systemctl enable --now sagi-pool-sync"
echo "5) sudo nginx -t && sudo systemctl reload nginx"
