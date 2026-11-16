# SAGI POOL · 中国大陆正式部署

目标：让球房访问一个中国大陆 HTTPS 域名，例如：

https://pool.example.com

同一个域名同时提供：
- 记分端
- 球房控制台
- 第二台直播手机页面
- SAGI 销售授权后台
- /api 国内同步接口

前端在非 GitHub Pages 的 HTTPS 域名下会自动把当前域名识别为同步服务器，因此球房首次使用时不需要再填写 API 地址。

## 推荐服务器

- 腾讯云轻量应用服务器 / CVM
- 阿里云 ECS
- Ubuntu 22.04 / 24.04
- Node.js 20+
- Nginx
- 2核2G 对早期几十家球房足够做记分同步；直播视频本身不经过这个同步服务

## 部署

1. 准备中国大陆服务器和已备案域名。
2. 配置 HTTPS 证书。
3. 安装 Node.js 20+ 与 Nginx。
4. 在仓库中执行：

   chmod +x china-deploy/install.sh
   ./china-deploy/install.sh

5. 修改：

   /etc/sagi-pool-sync.env

   必须设置一个只由 SAGI 掌握的强管理员密钥。

6. 修改 Nginx 中的 pool.example.com 与证书路径。
7. 启动：

   sudo systemctl enable --now sagi-pool-sync
   sudo nginx -t
   sudo systemctl reload nginx

## 数据

早期版本把授权和比分状态保存在：

/opt/sagi-pool-sync/data.json

这适合 MVP 和前几十家门店。规模扩大后再平滑迁移到 MySQL/Redis，前端 API 不需要改变。

## 安全

- 正式环境启用 SAGI_REQUIRE_LICENSE=1
- SAGI_ADMIN_TOKEN 只保存服务器和 SAGI 自己的设备
- 球房只拿 Club ID + 球房同步密钥
- Nginx 只对公网暴露 443
- Node 只监听 127.0.0.1:8787
- 不要把管理密钥写进 GitHub


## 每日自动备份

部署包包含：

- `sagi-pool-backup.service`
- `sagi-pool-backup.timer`
- `backup.mjs`
- `restore.mjs`

默认每天约 04:10 执行一次 gzip 备份，并随机延迟最多 5 分钟，默认保留 14 天。

启用：

```bash
sudo systemctl enable --now sagi-pool-backup.timer
sudo systemctl list-timers | grep sagi-pool
```

手动测试：

```bash
sudo systemctl start sagi-pool-backup.service
ls -lh /opt/sagi-pool-sync/backups/
```

恢复必须先停止服务，并显式确认：

```bash
sudo systemctl stop sagi-pool-sync
cd /opt/sagi-pool-sync
sudo -u www-data env SAGI_DATA_FILE=/opt/sagi-pool-sync/data.json SAGI_CONFIRM_RESTORE=YES node restore.mjs /opt/sagi-pool-sync/backups/<backup>.json.gz
sudo systemctl start sagi-pool-sync
```

恢复脚本会在覆盖前自动保留一份 `data.json.pre-restore-*.bak`。
