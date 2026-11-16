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


## V2.5 心跳超时与假直播清理

- Android LIVE ENGINE 正常每 15 秒上报直播心跳。
- 默认 60 秒没有心跳后，后台下一次读取设备状态时自动关闭“直播中”。
- 自动生成 heartbeat_timeout 结束原因。
- 防止手机断电、进程被系统杀死或网络彻底中断后后台长期显示假直播。
- 超时时间可通过 SAGI_LIVE_HEARTBEAT_TIMEOUT_MS 配置。


## V2.6 数据保护与关机恢复

- 主数据文件继续使用 tmp → rename 原子替换。
- 每次持久化前，把上一份有效主文件复制为 .bak。
- 启动时如果主 data.json 无法解析，会自动尝试 data.json.bak。
- SIGTERM / SIGINT 时先同步持久化，再关闭 HTTP 服务。
- 部署更新、systemd 重启和云服务器正常关机时减少最后状态丢失风险。
- 自动自检会真实执行：写入 → 关机 → 重启 → 读取 → 故意破坏主文件 → .bak 恢复。


## V2.7 安装码防刷

- /api/provision/claim 按客户端 IP 做内存级速率限制。
- 默认每 60 秒最多 20 次领取尝试。
- 超限返回 HTTP 429 + Retry-After。
- Web / Android 显示“安装码尝试过多，请稍后再试”。
- 不引入 Redis，早期单机球房销售场景即可生效。
- 可通过 SAGI_PROVISION_RATE_LIMIT / SAGI_PROVISION_RATE_WINDOW_MS 调整。


## V2.8 管理员防刷

- /api/admin/* 统一经过管理员认证失败限速。
- 默认 5 分钟窗口内最多 10 次错误管理员密钥尝试。
- 超限返回 HTTP 429 + Retry-After。
- 正确管理员密钥永远可立即通过并清零该 IP 的失败计数，避免共享 NAT 下被恶意错误请求锁死。
- 可通过 SAGI_ADMIN_FAIL_LIMIT / SAGI_ADMIN_FAIL_WINDOW_MS 调整。


## V2.9 售后健康状态

- 新增管理员专属 GET /api/admin/status。
- 返回服务版本、运行时长、授权数量、设备数量、直播中数量和已同步球桌数量。
- 返回主数据/备份有效性与数据目录可写状态，但不暴露服务器文件路径和密钥。
- 手机销售后台提供“一键服务健康”面板。


## V2.11 续费与到期提醒

- 新增管理员续费接口，更新到期日/套餐/桌数时不更换主密钥和设备 token。
- 已到期或停用的球房续费后可重新激活。
- 管理员健康状态增加 30 天内即将到期数量。
- 手机销售后台显示即将到期客户，并提供一键续费 1 年。
