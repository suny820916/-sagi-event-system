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


## 交付与售后中心 V1.4

入口：`delivery-center.html`

- 独立交付轨道：待验货 → 验货异常 → 待交付 → 已签收 → 售后处理中 → 已关闭
- 已到货 / 待交付 / 已完成生产订单，以及已发货 / 已完成主订单自动进入交付池
- 验货清单：数量、姓名/号码、尺码、外观质量
- 售后异常类型：缺件、错码、错名/错号、质量问题、补单、其他
- 每条异常支持“已解决 / 重新打开”
- 存在未解决异常时禁止直接客户签收
- 可记录交付日期、签收人、签收日期、售后备注
- 客户签收会安全同步主订单为已完成
- 每单可设置复购提醒日期，到期后支持一键带原球队/联系人/款式/配色/人数进入重新报价
- 售后异常支持一键生成补单草稿，并带回原球队和原款式进入定制流程
- 从生产中心可以直接深链到对应交付单，从交付中心也可回到对应订单
- delivery 字段会随订单进入现有云端订单备份
- 交付中心不读取老板私有成本键，也不保存供应商身份或采购成本
- 已加入 PWA 离线缓存

### 交付数据边界

交付/售后信息保存在订单的 `delivery` 字段，包括验货状态、售后异常、签收记录、复购提醒和时间线。老板私有成本继续与订单分离，不进入客户交付记录。


## 商用验收版 V1.5

入口：`commercial-check.html`

本阶段停止堆功能，专门修复手机商用稳定性：

- 定制草稿 JSON 损坏时启用安全兜底，不再直接阻断页面
- localStorage 写入统一增加失败处理，存储空间不足时明确报警
- 队徽上传先压缩至最长边不超过 640px，再写入本机
- 拒绝 12MB 以上原始队徽，降低 iPhone Safari 存储爆满概率
- 订单确认增加重复点击锁，避免连续点击生成重复订单
- 订单历史写入失败时不会假装订单已经保存成功
- 报价保存 / 报价转订单增加存储失败保护
- 生产进度、交付/售后记录增加存储失败保护
- Service Worker 离线导航失败时回到 `start.html`，不再错误回到定制页
- 手机首页“今日待办”统一统计待确认、待下单、生产异常、售后异常、待签收与复购提醒
- 商用自检页会检查：
  - localStorage 可写
  - 草稿 / 订单 / 报价 JSON 可解析
  - 重复订单号
  - 订单关键结构
  - 生产 / 售后阶段合法性
  - 离线缓存是否齐全
  - Service Worker 是否实际控制页面
  - Canvas / FileReader 队徽压缩能力
  - Web Share 支持
  - 当前网络状态
  - 浏览器存储额度
- 支持导出 V1.5 自检报告
- 支持导出客户业务备份，不包含老板私有成本表
- `cloud-sync.js` 仍只同步显式订单对象，不枚举整个 localStorage

### 商用使用建议

每天第一次接单前打开 `commercial-check.html`。如果显示 PASS，可开始当天接单；如果出现 FAIL，应先处理失败项。WARN 通常代表非阻断能力，例如当前离线、系统分享不可用或 Service Worker 尚未接管当前页面。

V1.5 的 PASS 仍属于浏览器和源码级验收，不等同于真实 iPhone 机型上的完整人工点击验收，也不替代服务器端安全测试。


## V1.6 RC1 发布候选版

版本：`1.6.0-rc1`
发布元数据：`release.json`
状态：Release Candidate，尚未标记 Stable。

### RC1 发布加固
- 手机工作台负责注册 Service Worker，不再依赖先打开定制页
- 工作台每次联网打开会检查 PWA 更新
- 新 Service Worker 接管后自动重载工作台，并显示更新完成提示
- PWA manifest 固定 `id=./`、`scope=./`、`start_url=./start.html`
- iPhone 非 Safari / 非 PWA 环境显示接单建议
- 微信内置浏览器显示明确提示：正式接单、备份恢复、打印和 PWA 更新优先使用 Safari
- 商用自检升级到 V1.6 RC1
- 业务备份支持安全恢复
- 恢复仅允许业务白名单键，不允许导入额外 localStorage 键
- 恢复前先完整验证 JSON 和每个白名单值
- 恢复过程采用内存快照 + 写入失败自动回滚
- 老板私有成本 `sagi-kit-private-cost-v1` 不参与业务备份恢复
- 离线缓存加入 `release.json`
- Service Worker 离线导航继续回退到工作台
- RC1 自检报告文件名：`SAGI-KIT-V1.6-RC1-CHECK.json`

### Release Gate
- 当前 Service Worker 缓存清单中的文件：全部存在
- 手机工作台本地入口：全部有目标文件，无已知死链
- start.html / commercial-check.html / sw.js：脚本语法检查 PASS
- RC1 manifest / release metadata：PASS
- 云同步仍只同步显式订单对象：PASS
- GitHub PR #24 当前可合并，但仍为 Draft
- 当前 PR 头提交没有 GitHub status checks / workflow runs；仓库未提供自动 CI 证据，因此不能把“无 CI”表述为 CI PASS

### 仍未通过的最终发布边界
- 真实 iPhone Safari 全流程人工点击：NOT YET VERIFIED
- 微信内置浏览器人工点击：NOT YET VERIFIED
- PWA 从旧缓存升级到 RC1 的真实设备验证：NOT YET VERIFIED
- 低存储 / 长时间连续使用压力测试：NOT YET VERIFIED
- 业务备份导出 → 清空测试环境 → 恢复 → 数据逐项比对的真实设备演练：NOT YET VERIFIED
- 私有云服务器未启用，因此多设备冲突与服务器安全测试：NOT APPLICABLE

因此 V1.6 当前应称为 **RC1 源码发布候选通过**，不应称为最终 Stable。


## V1.6 Stable 真机验收门

入口：`stable-qa.html`

RC1 不能自动升级 Stable。真机验收页只负责在当前设备执行检查、记录人工结果和导出 QA 报告。

### 自动检查
- localStorage 基础写入
- 临时 512KB 写入/删除
- 临时 JSON 写入 → 读取 → 解析 → 清理往返
- 离线核心缓存
- Service Worker/PWA 控制状态
- `release.json` 是否仍为 `1.6.0-rc1 / stable=false`
- 当前设备/浏览器环境
- 浏览器存储额度
- 系统分享能力

### 必须人工确认的 6 项
1. iPhone Safari 全业务流程
2. 微信内置浏览器行为
3. 旧 PWA → RC1 更新
4. 离线完整回合
5. 业务备份真实导出 → 恢复 → 核对
6. 低存储 / 连续使用

### Stable Gate
只有“自动检查无 FAIL/WARN + 6 项人工验收全部 PASS”时，本机才显示 `READY FOR STABLE`。

验收结果可导出为：
`SAGI-KIT-V1.6-STABLE-QA.json`

该页面不会修改 `release.json`、不会合并 PR、不会写入正式订单/报价。最终 Stable 仍需在仓库中单独发布。


## Stable Promotion Gate

入口：`stable-promotion.html`

该页面用于把真实 iPhone 导出的 Stable QA 报告转换为仓库发布申请包。

### 接受条件
- QA schema 必须为 `SAGI-KIT-STABLE-QA-1`
- QA version 必须为 `1.6.0-rc1`
- `readyForStable=true`
- 自动检查必须全部 PASS
- 六项人工真机验收必须全部 PASS
- 报告时间有效
- 必须包含设备信息

### 输出
通过后生成：
`SAGI-KIT-V1.6-STABLE-PROMOTION.json`

申请包包含：
- 请求从 `1.6.0-rc1` 升级到 `1.6.0`
- QA 生成时间
- QA 自动检查 / 人工检查通过数量
- 原 QA 文件 SHA-256（浏览器支持 WebCrypto 时）
- 设备环境摘要
- 明确声明：需要仓库侧单独发布、不会自动合并、不会自动修改 release.json

### 安全边界
Stable Promotion Gate 没有 GitHub API 写入能力，不会修改订单/报价，不会修改 `release.json`，也不会把 RC1 自动升级为 Stable。

真正 Stable 发布必须在收到通过的 QA 报告和 Promotion 文件后由仓库侧单独执行。
