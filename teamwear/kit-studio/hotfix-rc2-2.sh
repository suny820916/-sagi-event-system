#!/usr/bin/env bash
set -Eeuo pipefail
APP=/opt/sagi-kit/site
BASE=https://raw.githubusercontent.com/suny820916/-sagi-event-system/99d75703182e050e1a8bfd9fe5771d766667bb45/teamwear/kit-studio
test -d "$APP" || { echo "ERROR: /opt/sagi-kit/site 不存在"; exit 1; }
curl -fsSL "$BASE/index.html" -o "$APP/index.html"
curl -fsSL "$BASE/sw.js" -o "$APP/sw.js"
docker restart sagi-kit-web >/dev/null
echo "SAGI KIT RC2 HOTFIX2: PASS"
echo "index.html + sw.js 已更新，底部可见 \\n 已清除。"
