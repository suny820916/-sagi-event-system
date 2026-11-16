# SAGI POOL LIVE ENGINE · Android V0.2

中国大陆优先的原生台球直播推流引擎。

## V0.2 已实现
- 原生后置摄像头预览
- 前后摄像头切换
- 后置摄像头手电筒控制
- 0.5x 步进变焦（按设备最大能力限制）
- 麦克风采集
- RTMP / RTMPS 任意合法推流地址
- 1280×720 横屏推流
- 900–1600 Kbps 自适应码率范围
- SAGI CHINA SYNC 比分拉取
- 球房商业授权错误提示
- 比分牌 Bitmap 真正编码进直播流
- 大金 / 小金 / 黄金9 / 胜局 / 8号球犯规事件层
- 三阶段事件展开效果后自动恢复小比分牌
- 弱网提醒
- 推流连接 / 重连 / 断开状态
- 实时码率 / FPS / 分辨率状态
- CI 自动编译并上传 APK

## 腾讯 LiteAV
固定使用：

com.tencent.liteav:LiteAVSDK_Live:13.5.0.20670

License 通过构建环境变量注入：
- TENCENT_LIVE_LICENSE_URL
- TENCENT_LIVE_LICENSE_KEY

正式 License 的 packageName 必须匹配 com.sagi.poollive（正式发布前可更换最终包名后再申请）。

## 下一步 V0.3
- 540p / 720p / 1080p 三档画质
- 音频开关
- RTMP 地址与球房配置安全保存
- 横屏“导演模式”精简 UI
- 开播前网络测速
- 本地录制备份
- Android 签名 Release APK / AAB
