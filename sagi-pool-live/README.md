# SAGI POOL LIVE · CHINA V2.8

面向中国大陆球房销售的手机台球直播、追分、球房管理、商业授权、设备管理和原生推流系统。

## 当前产品链路

球房销售流程已经闭环：

1. SAGI 销售后台开通球房授权。
2. 设置套餐、到期时间、最大球桌数。
3. 为指定球桌生成 8 位一次性安装码。
4. Android / Web 设备领取后得到独立设备 token。
5. 设备自动登记名称、球桌、最后在线时间。
6. 记分端、本店控制台、直播端通过中国大陆服务器同步。
7. Android LIVE ENGINE 把 SAGI 比分与追分事件真正编码进 RTMP / RTMPS。
8. 后台可以查看当前直播状态和最近直播记录。
9. 单台设备丢失或员工离职时可远程下线，不影响整家球房。
10. Android V1.0 RC1 收到远程下线后会硬停止 RTMP 与前台服务。

## Web / PWA

- 中式八球抢局
- 4球 / 6球 / 9球追分
- 2–4人
- 普胜 / 小金 / 大金 / 黄金9
- 赢家加分 / 输家等额扣分
- 当前击球球员、犯规、8号球犯规
- 撤销、新一局、比赛归零、历史日志
- 断网本地继续记分
- PWA 桌面安装
- 稳定设备 ID
- 一次性安装码
- 国内同域 HTTPS 自动识别

## CHINA SYNC V2.8

- Node.js 零第三方运行时依赖
- 腾讯云 / 阿里云大陆服务器
- 球房独立 Club ID
- 球房主密钥
- 设备专属 token
- 授权到期
- 最大球桌数
- 一次性安装码
- 设备清单
- 最近在线
- 设备远程下线
- 直播 start / heartbeat / stop / error
- “● 直播中”状态
- 码率 / FPS / 分辨率
- 最近 30 场直播会话
- 60 秒没有直播心跳自动结束假直播
- 原子持久化 + 有效 .bak 备份
- 主数据损坏自动从 .bak 恢复
- SIGTERM/SIGINT 优雅落盘\n- 安装码按 IP 限速，超限 HTTP 429\n- 管理员错误密钥防刷，正确密钥可立即恢复
- remote_revoke 自动关闭服务器直播状态

## Android LIVE ENGINE V1.0 RC4

- RTMP / RTMPS 原生推流
- 540P / 720P / 1080P
- 前后摄像头
- 灯光
- 变焦
- 麦克风开关
- 导演模式
- 弱网 / 重连 / 实时码率 / FPS / 分辨率
- SAGI 比分牌烧入直播流
- BIG GOLDEN / SMALL GOLDEN / GOLDEN 9 / RACK WIN / 8-BALL FOUL
- Android Keystore + AES/GCM 加密配置
- 配置管理 PIN
- 一次性安装码
- 稳定设备 ID
- 开播前健康检查
- camera / microphone 前台服务
- 常驻直播通知
- 直播会话心跳
- 远程下线后 1 秒级硬停止推流
- 可选固定商业签名流水线
- LiteAV 重连后仍断开时，应用层最多 3 次兜底恢复
- 本地隐私安全诊断日志

## 页面

- 记分端：`/sagi-pool-live/`
- 球房控制台：`/sagi-pool-live/club.html`
- Web 直播手机：`/sagi-pool-live/live.html`
- SAGI 销售授权后台：`/sagi-pool-live/admin.html`

## 中国大陆正式部署

`china-deploy/` 提供：
- Nginx 同域部署
- systemd 服务
- 环境变量模板
- HTTPS 入口结构
- Web + API 同一国内域名

正式商用需要：
- 中国大陆服务器
- 正式域名
- 按规定完成 ICP 备案
- HTTPS
- 强 SAGI_ADMIN_TOKEN

## Android 正式推流仍需要的生产资源

代码层已经预留，不写进 GitHub：

- `TENCENT_LIVE_LICENSE_URL`
- `TENCENT_LIVE_LICENSE_KEY`
- `SAGI_DEFAULT_SYNC_URL`
- Android 固定签名证书
- 直播平台或直播服务提供的合法 RTMP / RTMPS 地址

CI 在缺少这些生产 Secrets 时只生成 Debug APK；配置完成后会自动生成并验证可覆盖升级的商业签名 APK。

## 自动质量门禁

### Web / 国内服务
真实启动 CHINA SYNC 后测试：
- 授权开通 / 错误密钥 / 吊销
- 比分写入读取
- 最大球桌数
- 安装码一次性
- 设备 token
- 设备清单
- 单设备远程下线
- 直播 start / heartbeat / stop
- 直播会话历史
- remote_revoke 自动结束会话
- PWA 稳定设备身份

### Android
真实执行 Gradle：
- Java / LiteAV 编译
- APK 存在性校验
- Debug APK 上传
- 有生产 Secrets 时构建 Release APK
- apksigner 校验 Release APK
