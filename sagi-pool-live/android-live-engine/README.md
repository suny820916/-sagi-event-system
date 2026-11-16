# SAGI POOL LIVE ENGINE · Android V1.0 RC3\n\n面向中国大陆球房的原生台球直播推流引擎。

## V1.0 RC3 商业传输安全收口

- LiteAV 原生重连优先。
- SDK 最终进入 Disconnected 后，SAGI 看门狗再做应用层兜底恢复。
- 应用层最多 3 次恢复，间隔 5 / 10 / 15 秒，避免无限重启。
- 重新连接成功后自动清零恢复计数。
- 本地诊断日志保留最近 200 条关键事件。
- 日志不记录同步密钥，也不记录完整 RTMP 地址。
- SDK 错误文本中的 RTMP / RTMPS URL、token/secret/key 参数会二次自动脱敏。
- Debug 构建允许 HTTP 便于本地测试；Release 构建禁止明文 HTTP。
- Release 安装码领取和开播预检都强制国内同步地址使用 HTTPS。
- 诊断面板可查看、复制和清空最近日志。
- 后端 60 秒心跳超时自动清理假直播。


## V0.9 远程硬停播与直播日志

- 后台远程下线设备后，比分轮询收到授权失效会触发硬停止。
- 1 秒级停止 RTMP 推流。
- 同时撤销 Android 前台直播服务与常驻通知。
- 清空当前设备同步密钥，要求重新使用安装码授权。
- 直播开始后上报 start。
- 每 15 秒上报码率/FPS/分辨率心跳。
- 正常停止上报 stop。
- 推流错误上报 error。
- 后台可看到“● 直播中”与最近直播会话。
- 直播日志上报失败不会影响实际推流。\n\n## V0.8 设备身份与远程下线

- 首次安装自动生成稳定设备 ID
- 设备 ID 使用 Keystore 加密配置一起保存
- 安装码领取时上报手机品牌/型号作为设备名称
- 后台可查看设备绑定球桌、首次安装、最近在线
- 销售后台可单独远程下线设备；该设备后续同步会收到授权失效
- 下线单台设备不会影响球房主授权和其他手机

## V0.7 配置锁与商业签名\n\n### 普通员工模式\n- 设置 4–8 位管理 PIN\n- PIN 通过 Android Keystore 加密保存\n- 锁定后禁止修改国内同步服务器、Club ID、球桌编号、设备同步密钥、RTMP / RTMPS 推流地址和一次性安装码领取\n- 员工仍可使用开播/停止、镜头切换、灯光、变焦、画质、麦克风和导演模式\n\n### 商业 Release 签名\nCI 现在支持可选商业签名构建。需要在 GitHub Secrets 中配置：\n- SAGI_ANDROID_KEYSTORE_B64\n- SAGI_ANDROID_KEYSTORE_PASSWORD\n- SAGI_ANDROID_KEY_ALIAS\n- SAGI_ANDROID_KEY_PASSWORD\n- TENCENT_LIVE_LICENSE_URL\n- TENCENT_LIVE_LICENSE_KEY\n- SAGI_DEFAULT_SYNC_URL\n\n配置完成后会同时构建 Debug APK 和签名 Release APK，并用 Android apksigner 验证签名。使用同一签名证书后，球房后续版本可直接覆盖升级。\n\n签名私钥与直播密钥不会写入 GitHub 源码。\n\n## V0.6\n- camera / microphone 前台服务\n- 常驻直播通知\n- Home 后提升长时间直播稳定性\n\n## V0.5\n- 开播前健康检查：国内服务器、球房授权、桌数、权限、RTMP、LiteAV License\n\n## V0.4\n- 一次性安装码\n- 设备专属 token\n- 国内服务器预置\n- Keystore + AES/GCM 加密配置\n\n## 当前直播能力\n- 中式八球 / 4球 / 6球 / 9球追分\n- SAGI 比分牌真正烧入 RTMP 视频\n- BIG GOLDEN / SMALL GOLDEN / GOLDEN 9 / RACK WIN / 8-BALL FOUL\n- 540P / 720P / 1080P\n- 前后镜头、灯光、变焦\n- 弱网 / 重连 / 实时码率 / FPS / 分辨率\n- 导演模式\n- 国内多手机同步\n- 球房商业授权\n\n## 下一阶段 V0.9\n- 自动生成球房专属安装包\n- 推流地址快速导入\n- 更完整的断流恢复与开播日志\n- 本地录像备份\n- 设备管理与远程下线