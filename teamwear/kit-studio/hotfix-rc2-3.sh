#!/usr/bin/env bash
set -Eeuo pipefail
APP=/opt/sagi-kit/site
BASE=https://raw.githubusercontent.com/suny820916/-sagi-event-system/e7aa10851eaf214a04a8165e47846f7b55783d39/teamwear/kit-studio
test -d "$APP" || { echo "ERROR: /opt/sagi-kit/site 不存在"; exit 1; }
curl -fsSL "$BASE/quote.html" -o "$APP/quote.html"
curl -fsSL "$BASE/index.html" -o "$APP/index.html"
curl -fsSL "$BASE/sw.js" -o "$APP/sw.js"
docker restart sagi-kit-web >/dev/null
echo "SAGI KIT RC2 HOTFIX3: PASS"
echo "报价转正式订单跳转链已修复，PWA 缓存已更新。"
