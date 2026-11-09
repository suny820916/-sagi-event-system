# SAGI CLOUD BRIDGE

SAGI CONTENT OS 的 Instagram 云端直下服务。

## 功能

- 手机 5G / 任意网络可用，不要求与电脑同一 Wi-Fi
- Instagram Reel / Post -> yt-dlp -> MP4
- 异步任务：创建 -> 下载中 -> READY -> 手机下载
- Bearer Token 保护
- 只允许 instagram.com 域名
- 默认单文件上限 500MB
- 临时文件 30 分钟自动清理

## 部署

### Render
仓库根目录已提供 `render.yaml`。连接 GitHub 仓库后用 Blueprint 部署即可。

部署完成后，在 Render 环境变量中查看自动生成的 `SAGI_BRIDGE_TOKEN`。

### Railway
也可使用仓库根目录 `railway.toml`，并手动添加：

```
SAGI_BRIDGE_TOKEN=你自己生成的一长串随机字符
SAGI_MAX_FILE_MB=500
SAGI_JOB_TTL_MIN=30
```

## CONTENT OS 设置

在 VIDEO DOWNLOAD 中选择：

- 下载引擎：CLOUD
- Cloud Bridge URL：例如 `https://sagi-cloud-bridge.onrender.com`
- Access Token：填 `SAGI_BRIDGE_TOKEN`

保存后，以后粘贴 Instagram 链接直接点“下载 INS 视频”。

仅用于你拥有或已获授权保存/使用的内容。
