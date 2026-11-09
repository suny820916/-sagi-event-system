# SAGI CLOUD BRIDGE

SAGI CONTENT OS 的 Instagram 云端直下后台。

## 已完成的一次性配置

- Render Blueprint：仓库根目录 `render.yaml`
- 服务名：`sagi-cloud-bridge-suny820916`
- Dockerfile：`sagi-cloud-bridge/Dockerfile`
- Docker Context：`sagi-cloud-bridge/`
- Region：Singapore
- Plan：Free
- Health Check：`/health`
- 自动生成服务器密钥
- 自动部署：main 分支后续提交自动更新
- 仅允许 CONTENT OS GitHub Pages Origin 激活
- 仅解析 Instagram URL
- 默认 300MB / 20次每小时 / 文件30分钟自动清理

## 第一次部署

使用 Deploy to Render：

https://render.com/deploy?repo=https%3A%2F%2Fgithub.com%2Fsuny820916%2F-sagi-event-system

登录 Render 后确认 Blueprint 并部署即可。部署完成后回到 CONTENT OS → DOWN → 激活 SAGI CLOUD。

日常使用不需要填写 URL、Token 或电脑地址。

仅用于你拥有或已获授权保存/使用的内容。
