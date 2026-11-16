# SAGI POOL LIVE ENGINE · Android V0.1

中国大陆优先的原生手机推流引擎。

## 当前工程能力

- 后置摄像头预览
- 麦克风采集
- RTMP / RTMPS 推流地址
- 1280×720 横屏直播参数
- SAGI CHINA SYNC 比分轮询
- 比分牌渲染为 Bitmap
- LiteAV setWatermark 将比分真正编码进直播流
- 球房授权错误提示
- 屏幕常亮

## LiteAV License

构建时通过环境变量注入，不写进 GitHub：

TENCENT_LIVE_LICENSE_URL
TENCENT_LIVE_LICENSE_KEY

正式 License 的 packageName 必须匹配 com.sagi.poollive（或后续正式包名）。

## 构建

JDK 17 + Android SDK 35。

gradle :app:assembleDebug

## V0.2 目标

- 摄像头切换 / 闪光灯 / 变焦
- 540p / 720p / 1080p 档位
- 弱网状态与自动重连 UI
- BIG GOLDEN / SMALL GOLDEN / WIN 事件动画水印
- 加密保存 RTMP 配置
- 生成可安装 APK
