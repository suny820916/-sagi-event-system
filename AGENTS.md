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
