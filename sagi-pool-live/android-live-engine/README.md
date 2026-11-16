# SAGI POOL LIVE ENGINE · Android V0.6

面向中国大陆球房的原生直播推流引擎。

## V0.6 长时间直播稳定性
- 开播成功前启动 Android 前台服务
- 前台服务声明 camera + microphone 类型
- 常驻“● 正在保持台球直播推流”通知
- 按 Home 后进程仍处于直播前台服务状态
- 推流启动失败自动撤销前台服务
- 正常停止直播自动关闭常驻通知
- Activity 真正销毁时同步关闭服务，避免“假直播”通知残留
- 屏幕保持常亮

## V0.5
- 开播前一键健康检查
- 国内服务器 / 球房授权 / 球桌权限 / 摄像头 / 麦克风 / RTMP / LiteAV License 检测

## V0.4
- 一次性安装码
- 设备专属 token
- SAGI_DEFAULT_SYNC_URL 国内域名预置
- Android Keystore + AES/GCM 加密配置

## 当前完整能力
- 中式八球 + 4/6/9球追分比分烧录
- 大金 / 小金 / 黄金9 / 胜局 / 8号球犯规直播包装
- 540P / 720P / 1080P
- 前后摄像头、灯光、变焦
- 麦克风开关
- 导演模式
- 弱网、重连、码率、FPS、分辨率监控
- RTMP / RTMPS
- 中国国内同步、商业授权、安装码

## 商用前仍需注入
- TENCENT_LIVE_LICENSE_URL
- TENCENT_LIVE_LICENSE_KEY
- SAGI_DEFAULT_SYNC_URL

## 下一阶段 V0.7
- 普通员工“配置锁定”
- Release 签名流水线
- 每个球房独立安装包配置
- 推流地址快速导入
