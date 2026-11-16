# SAGI CHINA SYNC V1.0

为中国大陆球房部署的零第三方依赖同步服务。

## 特点
- 只依赖 Node.js 内置模块，无 Supabase / Firebase / Cloudflare 依赖
- HTTPS 下通过 REST + SSE 同步球桌比分
- 单桌状态、本店全部球桌状态、断线重连
- JSON 文件持久化，适合 CLUB MVP
- 可部署腾讯云轻量应用服务器或阿里云 ECS
- 可设置 `SAGI_SYNC_TOKEN` 保护接口

## 启动
```bash
SAGI_SYNC_TOKEN=change-me PORT=8787 node server.mjs
```

健康检查：`GET /health`

## API
- `GET /api/rooms/:clubId/:table`
- `POST /api/rooms/:clubId/:table`
- `GET /api/rooms/:clubId/:table/events`
- `GET /api/clubs/:clubId`

请求头：`X-SAGI-Token: <token>`

## 中国大陆正式商用
正式域名使用大陆服务器时，需要按当地要求完成 ICP 备案并配置 HTTPS。建议前置 Nginx，Node 服务只监听内网端口。

V1 使用单进程 JSON 持久化；当门店数扩大后升级为 MySQL/Redis，不改变前端 API。


## V2.2 设备安装码

销售后台可以为指定 Club ID + 球桌生成 8 位一次性安装码：

- 10 分钟有效
- 使用一次立即失效
- Android 端领取后获得设备专属 token
- 设备 token 只保存 SHA-256 哈希在服务器
- 球房主授权密钥无需交给普通员工
- 设备 token 同样受套餐到期与最大球桌数约束

接口：
- `POST /api/admin/provisions`（管理员）
- `POST /api/provision/claim`（安装设备）


## V2.3 设备管理

- 每次安装码领取会创建独立设备 token。
- 服务器保存设备 ID、标签、球桌、首次安装时间和最近在线时间。
- 销售后台可查看每家球房的设备清单。
- 可以单独远程下线某台设备，不影响球房主授权和其他设备。
- 授权列表显示有效设备数量。


## V2.4 直播会话与远程停播

- Android LIVE ENGINE 上报直播开始、15秒心跳、停止与推流错误。
- 设备后台显示当前是否正在直播、码率、FPS、分辨率。
- 每台设备保留最近 30 场直播会话。
- 直播记录保存开始/结束时间、结束原因、峰值/最低码率、最后 FPS 与分辨率。
- 后台远程下线设备时会立即关闭服务器端“直播中”状态并记录 remote_revoke。
- Android V0.9 收到设备授权失效后会立即停止 RTMP 与前台服务。
