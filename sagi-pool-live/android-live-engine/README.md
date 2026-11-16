# SAGI POOL LIVE ENGINE · Android V0.5

中国大陆优先的原生台球直播推流引擎。

## V0.5 开播前健康检查
“开始直播”现在先经过预检：
- 国内 SAGI CHINA SYNC /health
- Club ID / 设备密钥
- 球房授权是否有效
- 球桌是否超出购买数量
- 摄像头权限
- 麦克风权限（仅在麦克风开启时要求）
- RTMP / RTMPS 地址格式
- LiteAV License URL / Key 是否注入

也提供单独“开播检测”按钮，球房可以在比赛前先确认全部条件。

## V0.4
- 销售后台生成 8 位一次性安装码
- 10 分钟有效、使用一次立即失效
- Android 输入安装码自动领取 Club ID / 球桌 / 设备专属 token
- 正式构建可通过 SAGI_DEFAULT_SYNC_URL 预置国内服务器地址
- 安装后配置用 Android Keystore + AES/GCM 加密保存

## 已有直播能力
- 540P / 720P / 1080P
- 麦克风开关
- 前后镜头、灯光、变焦
- 导演模式
- 弱网与实时码率/FPS/分辨率
- RTMP / RTMPS
- 中八 / 追分比分烧录
- BIG GOLDEN / SMALL GOLDEN / GOLDEN 9 / RACK WIN / 8-BALL FOUL

## 正式构建需要
环境变量：
- TENCENT_LIVE_LICENSE_URL
- TENCENT_LIVE_LICENSE_KEY
- SAGI_DEFAULT_SYNC_URL

没有有效 LiteAV License 时，APK 可以完成界面、摄像头预览和国内同步测试，但 V0.5 会阻止正式推流并明确提示“SDK授权缺失”，避免球房现场误判成网络故障。

## 下一阶段 V0.6
- 长时间直播稳定性
- 前台服务与直播状态通知
- 配置锁定，普通员工隐藏敏感字段
- Release 签名构建
- 自动生成球房安装包
