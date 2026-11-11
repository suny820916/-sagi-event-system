# SAGI AI LOCAL V1.1 · AI ENGINE

手机优先的本地商家 AI 内容工作台。

## V1.1
- 云端 AI 真实生成接口：`/api/local-ai/generate`
- 商家 BRAND MEMORY 进入 AI 上下文
- 一句话生成主标题 / 海报方向 / 15秒视频 / 抖音 / 朋友圈
- 每次生成 3 个不同创意方向
- 清晰度 / 转化 / 品牌感 / 综合评分
- 云端失败自动 LOCAL FALLBACK，不中断工作
- 前端不保存或暴露 API Key
- 按 IP 的 AI 小时限流保护成本
- PWA 缓存升级到 V1.1

## Cloud
复用现有 `sagi-cloud-bridge-suny820916` Render 服务。
服务端环境变量 `OPENAI_API_KEY` 存在时启用真实 AI；默认模型为 `gpt-6-luna`，可用 `SAGI_LOCAL_AI_MODEL` 覆盖。

## 安全
不把密钥放 GitHub Pages；服务端提示词要求不编造价格、折扣、销量、评价或稀缺性。
