# SAGI AI LOCAL V1.2 · AI VISUAL

手机优先的本地商家 AI 内容与视觉工作台。

## V1.2
- 保留 V1.1 一句话 AI 内容引擎
- 新增视觉接口：`/api/local-ai/visual`
- 上传菜品 / 商品 / 门店 / 服务照片后，AI识别主体、场景、优势与问题
- 输出 3:4 海报方向、9:16 短视频封面方向、15秒视觉脚本、发布文案
- AI返回可执行的 cropFocus / overlayPosition / contrastOverlay，前端直接用于自动排版
- 浏览器本地 Canvas 生成 900×1200 与 900×1600 PNG，可直接保存
- 图片上传前在手机端压缩到最长边约1600px，降低流量与推理成本
- 云端AI不可用时自动 LOCAL VISUAL FALLBACK，仍能生成可用海报
- 不把 API Key 写入 GitHub Pages
- 对上传图片做 MIME / 大小校验，默认上限 8MB
- PWA 缓存升级到 V1.2

## Cloud
复用 `sagi-cloud-bridge-suny820916` Render 服务。
`OPENAI_API_KEY` 存在时启用真实 AI；默认模型 `gpt-6-luna`。
GPT-6 Luna 支持 Responses API、图片输入和 Structured Outputs，适合高频低成本视觉分析。

## 隐私与安全
照片只用于当前视觉分析请求，不写入商家 BRAND MEMORY。
视觉提示词禁止从人物照片推断身份或敏感属性，也禁止编造价格、折扣、销量、评价、奖项或品牌事实。
