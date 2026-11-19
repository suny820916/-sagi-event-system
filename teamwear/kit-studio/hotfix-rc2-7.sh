#!/usr/bin/env bash
set -Eeuo pipefail
APP=/opt/sagi-kit/site
START=https://raw.githubusercontent.com/suny820916/-sagi-event-system/a02ffa941931eb7a945a5119cfb15f3dcceaca8d/teamwear/kit-studio/start.html
SW=https://raw.githubusercontent.com/suny820916/-sagi-event-system/0beb3be93ef49a558c22a81aef61c81229164df5/teamwear/kit-studio/sw.js
test -d "$APP" || { echo "ERROR: /opt/sagi-kit/site 不存在"; exit 1; }
curl -fsSL "$START" -o "$APP/start.html"
curl -fsSL "$SW" -o "$APP/sw.js"
docker restart sagi-kit-web >/dev/null
echo "SAGI KIT RC2 HOTFIX7: PASS"
echo "iPhone PWA 离线启动链已更新：manifest/iOS 元信息 + 容错核心缓存 + 离线回落。"
