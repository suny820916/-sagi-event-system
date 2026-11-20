#!/usr/bin/env bash
set -Eeuo pipefail
APP=/opt/sagi-kit/site
BASE=https://raw.githubusercontent.com/suny820916/-sagi-event-system/5fb634b2019784f82d1a8caddda15decede3c060/teamwear/kit-studio
test -d "$APP" || { echo "ERROR: /opt/sagi-kit/site 不存在"; exit 1; }
for f in stable-qa.html commercial-check.html sw.js; do
  curl -fsSL "$BASE/$f" -o "$APP/$f"
done
docker restart sagi-kit-web >/dev/null
echo "SAGI KIT RC2 HOTFIX8: PASS"
echo "最终验收工具已更新：一键剩余自动验收 + RC2商用自检 + 安全备份白名单。"
