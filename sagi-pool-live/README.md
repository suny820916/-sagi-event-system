# SAGI POOL LIVE · CHINA V2.2

面向中国大陆球房销售的手机台球直播、追分、球房管理、商业授权和原生推流系统。

## Web / PWA 比赛端
- 中式八球抢局
- 4球 / 6球 / 9球追分
- 2–4人
- 普胜 / 小金 / 大金 / 黄金9 自定义分值
- 赢家加分 / 输家等额扣分
- 当前击球球员、犯规、8号球犯规
- 撤销、新一局、比赛归零、历史日志
- 本地断网继续记分
- PWA 桌面安装
- 一次性安装码领取球房配置

## 球房与多手机
- 1–12桌控制台
- 每桌独立入口与数据
- 记分手机 ↔ 国内服务器 ↔ 直播手机
- 第二台手机专用直播屏
- 国内同域 HTTPS 自动识别
- 腾讯云 / 阿里云大陆部署包

## 商业授权
- 每店独立 Club ID
- TRIAL / CLUB / CLUB PRO
- 到期时间
- 最大球桌数
- 球房主密钥 SHA-256 哈希保存
- 设备专属 token
- 8位一次性安装码：10分钟、一次即失效
- 授权吊销
- 手机销售授权后台

## Android LIVE ENGINE
已推进到 V0.6：
- RTMP / RTMPS 原生推流
- 540P / 720P / 1080P
- 前后摄像头、灯光、变焦
- 麦克风开关
- 导演模式
- 弱网、重连、码率 / FPS / 分辨率监控
- SAGI 比分牌真正编码进视频流
- BIG GOLDEN / SMALL GOLDEN / GOLDEN 9 / RACK WIN / 8-BALL FOUL
- Android Keystore + AES/GCM 加密配置
- 安装码自动领取设备配置
- 开播前健康检查
- camera / microphone 前台服务与直播通知
- GitHub CI 自动编译 APK

## 页面
- 记分端：`/sagi-pool-live/`
- 球房控制台：`/sagi-pool-live/club.html`
- Web 直播手机：`/sagi-pool-live/live.html`
- SAGI 销售后台：`/sagi-pool-live/admin.html`

## 国内服务端
`china-sync/` 不依赖 Firebase / Supabase / Cloudflare 等海外 BaaS，运行时只需要 Node.js。

正式部署建议：
- 腾讯云轻量应用服务器 / CVM 或阿里云 ECS
- 中国大陆正式域名
- HTTPS
- 按规定完成 ICP 备案
- `SAGI_REQUIRE_LICENSE=1`
- 强 `SAGI_ADMIN_TOKEN`

## 自动质量门禁
Web 商业自检会真实启动服务并测试：
- 授权开通 / 错误密钥 / 到期与吊销
- 比分写入与读取
- 整店球桌状态
- 最大球桌数
- 一次性安装码
- 安装码不可二次使用
- 设备专属 token

Android CI 会真实执行 Gradle 编译、校验 APK 并上传构建产物。

## 商用前必须补齐
Android 真正向直播平台推流需要：
- `TENCENT_LIVE_LICENSE_URL`
- `TENCENT_LIVE_LICENSE_KEY`
- `SAGI_DEFAULT_SYNC_URL`
- 平台或直播服务提供的合法 RTMP / RTMPS 推流地址

代码不会把这些生产密钥写进 GitHub。
