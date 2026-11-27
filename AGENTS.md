# SAGI SPORTS Development Rules

## Product direction
SAGI SPORTS is a football brand built around everyday football.

Core brand:
- SAGI SPORTS
- 为身边的足球加油
- 记录平凡人的足球梦
- 让身边的足球被认真对待
- Red dot = 热爱
- A = ARDOR · AFIRE · ALIVE

Core products:
- SAGI KIT
- SAGI EVENT
- SAGI BROADCAST

Brand-wise these three are peers.
For user acquisition, SAGI EVENT is the primary entry point.

## SAGI EVENT strategic rule
SAGI EVENT must move toward:

**基础赛事管理永久免费，但体验做到尽可能专业。**

Free does not mean simplified, unfinished, unstable, or amateur.
The free product should be good enough that ordinary teams, schools, youth competitions, community leagues and amateur cups want to use it repeatedly.

Primary user promise:
- 无需注册即可开始
- 手机优先
- 创建赛事简单
- 赛程、比分、积分、晋级自动化
- 数据安全
- 操作符合比赛现场场景

Primary success condition:
A first-time user should be able to create a usable competition within 5 minutes.

## EVENT priority order

### P0 — reliability and match-day usability
1. Data safety
2. Automatic local save
3. Restore after refresh/reopen
4. Match-day mobile workflow
5. Score entry stability
6. Undo / confirmation for destructive actions
7. Never lose existing results because of regenerate/reset actions

### P1 — professional tournament management
1. Simplified event creation
2. Human-readable competition formats
3. Automatic schedule generation
4. Rest-time / back-to-back conflict checks
5. Multi-venue scheduling foundation
6. Automatic standings and qualification
7. Bulk team paste/import

### P2 — growth and sharing
1. Public read-only event page
2. Shareable schedule / results / standings
3. SAGI-branded export images
4. Cloud sync when architecture is ready

Do not jump to P2 while P0 is unstable.

## User experience rules
- Chinese is the primary UI language.
- SAGI EVENT may appear in English as the brand name, but primary navigation/actions must be Chinese.
- Prefer ordinary football language over developer terminology.
- Do not expose JSON as the main user concept. Use “备份赛事 / 恢复赛事”.
- Mobile is not a shrunk desktop layout. Design for one-handed sideline operation.
- Current match and next match must be obvious during match day.
- Important score buttons must be large and difficult to mis-tap.
- Do not add meaningless animation, gaming UI, decorative effects, or dashboard complexity.
- Professional means fast, clear, safe, predictable and reliable.

## Website navigation
Primary navigation must be Chinese:
- 首页 -> /home.html
- 球队装备 -> SAGI KIT
- 赛事 -> SAGI EVENT
- 直播 -> SAGI BROADCAST
- 关于我们 -> SAGI ABOUT

/index.html is the brand entry/splash page, not the normal navigation homepage.

## Visual rules
- Black / white / SAGI red
- Minimal
- International football brand feel
- Official SAGI logo must be preserved; do not redraw it
- SAGI red is an accent, not a large decorative effect
- Avoid cheap gradients, excessive glow, rings around the red dot, or unnecessary motion
- Mobile-first

## Architecture direction
Keep code, event data and large media separated:
- application/site code -> GitHub
- event structured data -> database when cloud sync/public pages are introduced
- photos/video/large media -> object storage + CDN

Do not solve future scale by putting large media directly into the Git repository.

## Development rules
Before changing code:
1. Read the current implementation and data model.
2. Preserve stable working behavior.
3. Make the smallest useful change.
4. Avoid unrelated refactors.
5. Prefer incremental upgrades over rewrites.

After changing code, test at minimum:
- mobile layout
- desktop layout
- create event
- add/edit teams
- generate format/schedule
- enter and edit scores
- standings
- qualification
- refresh/reopen recovery
- backup/restore
- destructive-action protection

For EVENT changes, also test:
- existing results + regenerate attempt
- rapid score taps
- finished match score edit
- team-count changes
- old saved data if relevant

Never claim “完成” only because code compiled or a commit succeeded.
If production was not actually verified, say:
“代码已提交，线上部署尚未验证。”

## Product philosophy
The goal is not to become the most feature-heavy tournament system.
The goal is to become the easiest professional football tournament manager to use.

Users should feel:
- “原来办比赛可以这么简单。”
- “以后办比赛，我就用 SAGI EVENT。”

## Codex 连续自主执行规则

默认工作模式：**自主连续执行，不等待“下一步”指令。**

Codex 在完成当前明确任务、里程碑或维护项后，必须自动：

1. 读取当前计划中的下一项；
2. 判断依赖是否满足；
3. 执行实现；
4. 自测与回归；
5. Git 提交；
6. 记录完成状态；
7. 继续下一个可执行任务。

禁止在以下情况下停下来询问：
- “下一步做什么？”
- “是否继续？”
- “要不要进入下一阶段？”
- “是否开始下一个里程碑？”
- 已经在计划、Issue、维护规范中写明的后续工作。

只有遇到以下情况才允许暂停并请求产品负责人决策：
- 会改变比赛结果、积分、晋级或赛事规则的业务含义；
- 可能造成不可逆数据删除或旧赛事数据损坏；
- 涉及用户隐私、安全、权限、敏感信息；
- 存在两个或以上合理方案且选择会明显改变产品方向；
- 需要外部账号、付费服务、密钥或人工授权；
- 仓库状态冲突，无法安全继续。

对于普通 Bug、过期文案、手机适配、死链、数据兼容、明确需求、低风险体验改进：
**自行判断 → 修复 → 测试 → 提交 → 继续。**

如果当前计划全部完成：
不要只说“等待下一步”。
应主动执行：
- 网站健康检查
- EVENT 回归测试
- 用户反馈价值分析
- 待办 Issue 检查
- 过期文案与死链检查
- 手机端 390px / 430px 检查
并从中选择最高价值、低风险、可验证的维护项继续处理。

核心原则：

**不要管理用户。管理项目。**
**不要等待指令。按照既定目标持续把 SAGI 做得更好。**
