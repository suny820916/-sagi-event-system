# SAGI AI LOCAL V1.4 · CHINA DEPLOY

这是国内生产版代码，和现有海外研发版分开。

## 目标
- 国内服务器同域部署
- 基础海报不依赖 AI
- 登录 / 商家档案 / 图片上传 / 历史记录 / 用量统计
- EDITORIAL / BRAND SPLIT / IMPACT 三套海报
- OpenAI-compatible AI 网关可替换，不把供应商写死
- Docker 一键部署

## 目录
- server/ FastAPI 后端
- web/ 手机端前端
- Dockerfile 容器镜像
- docker-compose.yml 单机生产部署
- .env.example 环境变量模板

## 本地或服务器启动
1. 复制 .env.example 为 .env
2. 修改 SAGI_SECRET
3. 在 sagi-local-china 目录运行 docker compose up -d --build
4. 访问 http://服务器IP:8080

## AI
不配置 AI_BASE_URL / AI_API_KEY / AI_MODEL 时：
- 登录正常
- 商家档案正常
- 图片上传正常
- 三套海报正常
- 历史记录正常
- 文案与视觉判断使用本地兜底

配置可在中国大陆稳定访问的 OpenAI-compatible 网关后：
- 文案 AI 自动启用
- 视觉 AI 自动启用
- 前端代码不用修改

## 正式生产
建议在国内云服务器前配置域名、HTTPS、CDN/对象存储。当前 V1.4 已经把代码与海外 GitHub Pages / Render / OpenAI 运行依赖解耦；GitHub 只继续承担研发和版本管理。
