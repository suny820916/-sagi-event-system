# SAGI POOL LIVE · V1.0 商用发布清单

目标：把当前 CHINA V2.5 + Android V1.0 RC1 从“可安装测试版”推进到“中国大陆球房可长期销售的正式版”。

## 1. 中国大陆服务器
- 腾讯云轻量/CVM 或阿里云 ECS。
- Linux + Node.js 20+ + Nginx。
- 正式域名解析到大陆服务器。
- 按规定完成 ICP 备案。
- HTTPS 证书有效。
- Nginx 仅公网暴露 443。
- Node 同步服务仅监听 127.0.0.1:8787。
- SAGI_REQUIRE_LICENSE=1。
- SAGI_ADMIN_TOKEN 使用高强度随机值。
- SAGI_ALLOW_ORIGIN 只允许正式前端域名。
- data.json 做每日备份；客户规模扩大后迁移 MySQL/Redis。

## 2. Android 正式签名
GitHub Secrets：
- SAGI_ANDROID_KEYSTORE_B64
- SAGI_ANDROID_KEYSTORE_PASSWORD
- SAGI_ANDROID_KEY_ALIAS
- SAGI_ANDROID_KEY_PASSWORD

要求：
- 商业签名私钥只由 SAGI 掌握。
- 以后所有版本使用同一签名，确保球房可以覆盖升级。
- CI 的 apksigner verify 必须通过。

## 3. 腾讯 LiteAV
GitHub Secrets：
- TENCENT_LIVE_LICENSE_URL
- TENCENT_LIVE_LICENSE_KEY

要求：
- 正式 License 绑定最终 Android packageName。
- 当前 packageName：com.sagi.poollive。
- 如果正式版要改包名，必须先改包名再申请/绑定正式 License。
- 开播前健康检查必须显示 SDK 授权正常。

## 4. 国内同步域名
GitHub Secret：
- SAGI_DEFAULT_SYNC_URL

要求：
- 使用 HTTPS，例如 https://pool.example.com。
- Android 安装后默认填入该地址。
- Web/PWA 同域部署时自动识别当前域名。
- /health、/api/rooms、/api/clubs、/api/provision/claim 均通过。

## 5. 直播平台
- 使用平台或直播服务合法提供的 RTMP / RTMPS 推流地址。
- 不把长期推流密钥写入源码。
- Android 使用 Keystore + AES/GCM 保存。
- 员工模式锁定后不可查看/修改推流配置。

## 6. 球房安装流程验收
- 销售后台创建球房授权。
- 设置套餐、到期日、最大球桌数。
- 指定球桌生成 8 位一次性安装码。
- Android 输入安装码领取设备专属 token。
- 后台正确显示设备型号、球桌、最近在线。
- 同一设备重新授权时更新原设备，不产生幽灵设备。
- 管理 PIN 锁定敏感配置。

## 7. 直播功能验收
- 540P。
- 720P。
- 1080P。
- 前后摄像头。
- 灯光。
- 变焦。
- 麦克风开关。
- 导演模式。
- 比分牌烧入 RTMP。
- BIG GOLDEN。
- SMALL GOLDEN。
- GOLDEN 9。
- RACK WIN。
- 8-BALL FOUL。
- 弱网提示。
- SDK 自动重连。
- SAGI 应用层最多 3 次兜底恢复。
- Android 前台服务。
- Home 后常驻直播通知。

## 8. 商业安全验收
- 错误 Club token → 401。
- 超出购买桌数 → 403。
- 到期授权拒绝。
- 球房总授权可停用。
- 单设备可远程下线。
- 远程下线后 Android 1 秒级停止 RTMP。
- 远程下线不会影响其他设备。
- 60 秒无心跳自动清理假直播。
- 直播日志不包含完整 RTMP 地址或同步密钥。

## 9. 网络压力测试
至少分别测试：
- 球房 Wi-Fi 稳定网络 2 小时。
- 5G 网络 1 小时。
- Wi-Fi → 5G 切换。
- 5G → Wi-Fi 切换。
- 断网 10 秒恢复。
- 断网 30 秒恢复。
- 路由器重启。
- 手机锁屏/返回桌面。
- 低电量模式。
- 手机发热状态。

记录：
- 是否丢直播。
- 自动恢复耗时。
- 是否继续同步比分。
- 是否出现假直播状态。
- 平均/最低码率。
- 是否需要人工干预。

## 10. 正式发布判定
只有以下全部满足才从 RC 升为 V1.0：
- Web/CHINA self-check 全绿。
- Android CI 全绿。
- 商业签名 APK 构建成功。
- apksigner 校验通过。
- LiteAV 正式 License 生效。
- 国内正式域名可访问。
- 真机 RTMP 推流成功。
- 至少完成一次 2 小时稳定直播测试。
- 远程下线、心跳超时、弱网恢复均实测通过。

未达到以上条件时继续保持 RC，不把测试版当正式商用品。
