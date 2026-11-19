#!/usr/bin/env bash
set -Eeuo pipefail
APP=/opt/sagi-kit/site
INDEX=https://raw.githubusercontent.com/suny820916/-sagi-event-system/022bfb57e7f6e95bd087799cdb754769b6090f86/teamwear/kit-studio/index.html
SW=https://raw.githubusercontent.com/suny820916/-sagi-event-system/bc0def766d2b41d5f2ea5dd90cead0f4ac00442c/teamwear/kit-studio/sw.js
test -d "$APP" || { echo "ERROR: /opt/sagi-kit/site 不存在"; exit 1; }
curl -fsSL "$INDEX" -o "$APP/index.html"
curl -fsSL "$SW" -o "$APP/sw.js"
docker restart sagi-kit-web >/dev/null
echo "SAGI KIT RC2 HOTFIX4: PASS"
echo "完成页文案与面料中文显示已更新，PWA 缓存已提升。"
