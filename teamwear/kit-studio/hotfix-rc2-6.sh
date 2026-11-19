#!/usr/bin/env bash
set -Eeuo pipefail
APP=/opt/sagi-kit/site
BASE=https://raw.githubusercontent.com/suny820916/-sagi-event-system/48b7cb19342f133d133e8e890aabb226aecaf563/teamwear/kit-studio
test -d "$APP" || { echo "ERROR: /opt/sagi-kit/site 不存在"; exit 1; }
for f in order-history.html production-center.html delivery-center.html stable-qa.html sw.js; do
  curl -fsSL "$BASE/$f" -o "$APP/$f"
done
docker restart sagi-kit-web >/dev/null
echo "SAGI KIT RC2 HOTFIX6: PASS"
echo "状态机 + 真机验收测试订单一键重置工具已更新。"
