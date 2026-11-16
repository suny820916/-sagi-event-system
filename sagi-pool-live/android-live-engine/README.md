# SAGI POOL LIVE ENGINE · Android V0.3

中国大陆优先的原生台球直播推流引擎。

## V0.3
- 540P 流畅 / 720P 标准 / 1080P 高清三档
- 画质档位自动匹配目标与最低码率
- 麦克风一键开关
- Android Keystore + AES/GCM 加密保存：
  - 国内同步服务器
  - Club ID
  - 球桌编号
  - 球房同步密钥
  - RTMP / RTMPS 推流地址
  - 画质与音频偏好
- 不会为了保存方便把推流密钥明文落盘
- “导演模式”一键隐藏操作面板，只保留球台画面与直播比分
- SAGI POOL App 图标

## 已继承 V0.2
- 前后摄像头切换
- 后置灯光
- 变焦
- 弱网提醒
- 推流连接 / 重连 / 断开状态
- 实时码率 / FPS / 分辨率
- 中国国内比分同步与球房授权
- 大金 / 小金 / 黄金9 / 胜局 / 8号球犯规事件推流包装
- 动态 Bitmap 水印真正烧入 RTMP 视频流

## 直播 SDK
固定：
com.tencent.liteav:LiteAVSDK_Live:13.5.0.20670

License 通过构建环境变量注入：
- TENCENT_LIVE_LICENSE_URL
- TENCENT_LIVE_LICENSE_KEY

## 下一阶段 V0.4
- 开播配置向导：扫码导入球房、球桌、同步密钥
- 推流地址二维码/深链导入
- 开播前健康检查
- 本地录制备份
- Android 前台服务，提升长时间直播稳定性
- Release 签名流水线
