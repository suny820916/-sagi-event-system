#!/usr/bin/env bash
set -Eeuo pipefail
APP=/opt/sagi-kit/site
BASE=https://raw.githubusercontent.com/suny820916/-sagi-event-system/6c77ce96c3884b57e17a2cf629aed88da69bfbf4/teamwear/kit-studio
test -d "$APP" || { echo "ERROR: /opt/sagi-kit/site 不存在"; exit 1; }
curl -fsSL "$BASE/start.html" -o "$APP/start.html"
curl -fsSL "$BASE/sw.js" -o "$APP/sw.js"
docker restart sagi-kit-web >/dev/null
echo "SAGI KIT RC2 HOTFIX1: PASS"
echo "start.html + sw.js 已更新，PWA 缓存版本已提升。"
