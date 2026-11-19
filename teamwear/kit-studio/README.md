# SAGI KIT STUDIO V1.0 · CHINA READY

面向中国大陆手机用户的队服选款与订单原型。

## 当前已完成
- 22 个 SAGI 销售款号；公开客户包不保留厂家款式映射
- 五步客户流程：选款 → 定制 → 名单 → 核对 → 生成订单
- 手机优先 UI
- 本地自动保存草稿
- 断网后继续填写
- Service Worker 离线缓存
- 批量粘贴名单
- 重复号码/缺失信息校验
- 本地队徽预览
- 订单复制、系统分享、JSON 导出
- 不依赖 Google Fonts / Firebase / CDN / GitHub Raw 等客户端关键依赖

## 中国大陆部署原则
GitHub 只用于代码版本管理。正式商业部署不得让客户关键链路依赖 GitHub Pages 或境外 CDN。
正式版计划采用自有域名 + 中国大陆/香港可稳定直连服务器 + 自有对象存储；图片、订单、队徽、客户数据通过自有 API 处理。

## 数据安全
当前 V1 原型不会自动上传客户信息；数据保存在浏览器 localStorage。
接入正式 API 后，需要提供明确的提交状态、失败重试、幂等订单 ID 和后台同步确认。

## 供应链隔离
客户页面与公开订单只展示 SAGI 款号。厂家原始款号映射、成本与供应链资料不得进入公开客户包；未来如需维护，必须放在私有后台或受控数据源。

## 下一步
1. 将原 PDF 图册的 22 个系列切成 SAGI 客户展示图。
2. 新增真实商品图片懒加载与图片压缩。
3. 接入现有 teamwear 后台订单池。
4. 建立云端订单 API、队徽上传、自有对象存储。
5. 增加后台价格策略与客户报价层。


## V1.0 privacy / supply-chain boundary
The current GitHub repository is public. Therefore:
- Customer bundle MUST contain only SAGI product codes.
- Supplier names, supplier item mappings, negotiated costs and factory contact details MUST NOT be added to KIT STUDIO frontend source.
- Customer JSON export uses schema `SAGI-KIT-ORDER-1` and contains no supplier mapping.
- `admin-import.html` imports customer orders into the existing TEAMWEAR local order store without revealing supplier information.
- Production supplier mapping must later live in a private backend/private repository or another access-controlled store.

## Offline admin bridge
Open `kit-studio/admin-import.html`, choose a customer JSON order, then open `../index.html`.
The bridge merges the customer submission into `sagi_teamwear_sales_v122` without overwriting unrelated orders.


## 商品库 V1.0

入口：`catalog.html`

- 22 款 SAGI 客户商品档案（SK-001 ~ SK-022）
- 已对照当前用户图册核验款式配色、成人/青少年尺码与领型
- 支持款号、名称、配色和标签搜索
- 支持经典、个性、动感、年轻、简约、高级、东方分类
- 最多保留 3 款候选，适合客户与球队内部比较
- “选这款”会把 SAGI 款号带入 `index.html` 定制流程
- 商品库与数据文件已加入离线缓存
- SAGI推荐/青训推荐/上镜醒目等属于 SAGI 自有销售标签，不作为厂家销量声明

### 商品图片说明
当前商品图使用已核对图册的原款参考画面。界面会明确提示原有图片标识不代表最终 SAGI 贴牌成品，最终品牌位置以 SAGI A+红点确认稿为准。

### 供应链边界
公开商品库禁止出现厂家名称、厂家原始款号、成本、采购联系人或供应链映射。未来如需维护成本与供应商信息，必须放到私有服务或私有仓库。


## 报价成交 V1.1

入口：`quote.html`

- 可从 `catalog.html` 的任意 SK 款式一键进入报价
- 可输入球队、联系人、配色、成人/青训、面料、数量、销售单价与有效期
- 自动计算客户报价总额
- 销售单价由 SAGI 自行设置，第一次填写后本机记忆
- 本机保留最近报价，支持草稿 / 已发送 / 已成交
- 支持复制文本、系统分享与打印/保存报价单
- 客户确认成交后，把球队、款式、配色、人数等直接带入正式订单流程
- 会按报价人数预建名单行，减少重复操作
- 报价记录只包含客户销售价格，不包含厂家成本与供应链映射
- 报价页已加入 PWA 离线缓存

### 数据边界

报价记录使用 localStorage 键 `sagi-kit-quotes`。常用销售设置使用 `sagi-kit-quote-settings`。如果未来接入香港服务器，应只同步必要的客户订单/报价数据；成本、供应商、原厂款号映射继续放在私有后台。


## 成交与利润中心 V1.2

入口：`profit-center.html`

- 老板私有入口，首次打开设置 4–6 位本机 PIN
- PIN 仅防止客户随手查看，不等同于服务器级身份认证
- 成交额来自 `sagi-kit-quotes` 中状态为“已成交”的报价
- 私有成本保存在 `sagi-kit-private-cost-v1`
- 支持默认单套成本 + 22 款单独成本覆盖
- 自动计算本月成交额、毛利润、毛利率与成本覆盖率
- 成本未配置时明确显示“待补成本”，不会伪造完整利润
- 自动生成本月成交明细与畅销款式排行
- 支持私有成本 JSON 导出 / 导入备份
- 私有成本键不出现在商品库、客户报价、正式订单或云同步队列
- 当前 `cloud-sync.js` 仅同步显式加入队列的订单对象，不枚举浏览器 localStorage
- 页面已加入离线缓存

### 安全边界

当前 V1.2 仍是本机 localStorage 商业版。PIN 属于界面级隐私保护，不应视作强安全机制。正式接入香港/国内可稳定访问的私有服务器后，应把真实成本迁移到需要账号权限的私有 API 和数据库，并增加服务端鉴权、审计与加密备份。


## 生产中心 V1.3

入口：`production-center.html`

- 独立生产轨道：待下单 → 已下单工厂 → 生产中 → 已到货 → 待交付 → 已完成
- 已付款 / 生产中 / 已发货 / 已完成的现有订单自动进入生产池
- 老订单会根据原有订单状态自动映射到合理生产阶段，无需重新录入
- 每单可设置目标交付日期、内部生产备注与阶段历史
- 自动检查球队、联系人、SAGI款号、配色、名单、姓名、号码、尺码是否缺失
- 阶段超期阈值：待下单 1 天、已下单工厂 2 天、生产中 7 天、已到货 2 天、待交付 3 天
- 自动标记目标交付逾期
- “生产中”可同步推进主订单状态到生产中；生产完成时同步主订单为已完成
- 从生产中心可直接深链打开对应订单确认单
- 生产进度随订单对象进入现有订单云备份
- 生产中心不读取老板私有成本键，也不包含厂家身份/成本字段
- 已加入 PWA 离线缓存

### 生产数据边界

生产轨道保存在订单的 `production` 字段。允许保存生产阶段、交付日期、内部进度备注和阶段时间线；不应填写厂家联系方式、真实采购成本或老板私有利润数据。真实成本仍只保存在 `sagi-kit-private-cost-v1`，与生产订单分离。
