# SAGI KIT STUDIO V1.0 · CHINA READY

面向中国大陆手机用户的队服选款与订单原型。

## 当前已完成
- 22 个 SAGI 销售款号，后台保留厂家款式映射
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
客户页面只展示 SAGI 款号。厂家原始款号只保留在订单内部 supplierMapping 字段和管理端，不在客户 UI 中显示。

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
