#!/usr/bin/env bash
set -Eeuo pipefail
APP=/opt/sagi-kit/site
BASE=https://raw.githubusercontent.com/suny820916/-sagi-event-system/9e2022151db3a06c01768f9fd7907d58c8afd100/teamwear/kit-studio
test -d "$APP" || { echo "ERROR: /opt/sagi-kit/site 不存在"; exit 1; }
for f in order-history.html production-center.html delivery-center.html sw.js; do
  curl -fsSL "$BASE/$f" -o "$APP/$f"
done
docker restart sagi-kit-web >/dev/null
echo "SAGI KIT RC2 HOTFIX5: PASS"
echo "订单/生产/交付状态机已更新：订单中心止于已付款，客户签收才允许完成订单。"
