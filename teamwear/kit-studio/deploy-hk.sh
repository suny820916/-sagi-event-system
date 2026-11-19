#!/usr/bin/env bash
set -Eeuo pipefail

APP=/opt/sagi-kit
REPO=https://github.com/suny820916/-sagi-event-system.git
RELEASE_BRANCH=release/sagi-kit-v1.6.0-rc2

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: 请使用 root 执行此脚本。"
  exit 1
fi

for cmd in docker git curl ss; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "ERROR: 缺少命令 $cmd"; exit 1; }
done

PUBLIC_IP="$(curl -fsS --max-time 3 http://metadata.tencentyun.com/latest/meta-data/public-ipv4 2>/dev/null || true)"
if [ -z "$PUBLIC_IP" ]; then
  PUBLIC_IP="$(curl -fsS --max-time 6 https://api.ipify.org 2>/dev/null || true)"
fi
if ! printf '%s' "$PUBLIC_IP" | grep -Eq '^[0-9]{1,3}(\.[0-9]{1,3}){3}$'; then
  echo "ERROR: 无法自动读取公网 IPv4。"
  exit 1
fi
DOMAIN="$(printf '%s' "$PUBLIC_IP" | tr '.' '-').nip.io"

echo "=== SAGI KIT V1.6.0-RC2 香港部署 ==="
echo "PUBLIC_IP=$PUBLIC_IP"
echo "DOMAIN=$DOMAIN"

if ss -lntp | grep -Eq ':(80|443)[[:space:]]'; then
  echo "ERROR: 80 或 443 端口已被占用。为避免破坏现有服务，部署已停止。"
  ss -lntp | grep -E ':(80|443)[[:space:]]' || true
  exit 1
fi

TMP="$(mktemp -d /tmp/sagi-kit-rc2.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

echo "[1/6] 下载固定 RC2..."
git clone --depth 1 --branch "$RELEASE_BRANCH" "$REPO" "$TMP/repo"
test -f "$TMP/repo/teamwear/kit-studio/release.json" || { echo "ERROR: RC2 文件缺失"; exit 1; }
grep -q '"version": "1.6.0-rc2"' "$TMP/repo/teamwear/kit-studio/release.json" || { echo "ERROR: 版本校验失败"; exit 1; }

echo "[2/6] 安装站点文件..."
mkdir -p "$APP/site"
rm -rf "$APP/site"/*
cp -a "$TMP/repo/teamwear/kit-studio/." "$APP/site/"

echo "[3/6] 生成 HTTPS 配置..."
cat > "$APP/Caddyfile" <<EOF
$DOMAIN {
    root * /srv
    encode zstd gzip
    @root path /
    redir @root /start.html 302
    file_server
    header {
        X-Content-Type-Options nosniff
        X-Frame-Options DENY
        Referrer-Policy strict-origin-when-cross-origin
    }
}
EOF

echo "[4/6] 拉取 Caddy..."
docker pull caddy:2-alpine

echo "[5/6] 启动容器..."
docker rm -f sagi-kit-web >/dev/null 2>&1 || true
docker run -d \
  --name sagi-kit-web \
  --restart unless-stopped \
  -p 80:80 \
  -p 443:443 \
  -p 443:443/udp \
  -v "$APP/site:/srv:ro" \
  -v "$APP/Caddyfile:/etc/caddy/Caddyfile:ro" \
  -v sagi_caddy_data:/data \
  -v sagi_caddy_config:/config \
  caddy:2-alpine >/dev/null

echo "[6/6] 等待 HTTPS..."
URL="https://$DOMAIN/start.html"
OK=0
for i in $(seq 1 18); do
  if curl -fsSI --max-time 8 "$URL" >/dev/null 2>&1; then
    OK=1
    break
  fi
  sleep 3
done

echo
if [ "$OK" -eq 1 ]; then
  echo "========================================"
  echo "SAGI KIT RC2 DEPLOYMENT: PASS"
  echo "URL: $URL"
  echo "========================================"
  curl -fsSI --max-time 10 "$URL" | head -n 6 || true
else
  echo "========================================"
  echo "SAGI KIT RC2 DEPLOYMENT: HTTPS NOT READY"
  echo "URL: $URL"
  echo "========================================"
  echo "最近 Caddy 日志："
  docker logs --tail 80 sagi-kit-web || true
  exit 2
fi
