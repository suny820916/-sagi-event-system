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
