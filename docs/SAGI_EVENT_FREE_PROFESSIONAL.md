# SAGI EVENT — 免费却最专业

## Product thesis
SAGI EVENT is the main acquisition entry for SAGI SPORTS.

The strategy is:
免费赛事管理 -> 用户开始办比赛 -> 需要球队装备时认识 SAGI KIT -> 需要直播时认识 SAGI BROADCAST -> 需要完整赛事服务时认识 SAGI SPORTS。

The basic tournament-management experience should remain free.
Do not introduce login walls, membership tiers, ads, payment gates, or artificial limitations before the core experience is excellent.

## Current development target
Improve the existing EVENT implementation incrementally. Do not rewrite the stable core unless a concrete defect requires it.

### First experience
Landing copy should communicate immediately:
- SAGI EVENT
- 免费赛事管理
- 办一场比赛，不应该这么麻烦。
- 球队、赛程、比分、积分、晋级，一部手机就能管理。
- 免费创建赛事
- 无需注册 · 免费使用 · 手机即可管理

If an existing event is present, provide a clear “继续管理赛事” path.

### Event creation
Target flow:
1. 赛事名称
2. 地点 / 日期
3. 球队数量
4. 选择赛制
5. 球队录入
6. 自动生成赛事

Advanced scheduling settings should not block the first-time flow.

### Format selection
Explain each format in user language, including:
- suitable use case
- approximate match count
- minimum matches per team where applicable
- basic format behavior

Supported existing formats should be preserved:
- 分组 + 淘汰
- 双败制
- 单循环

### Scheduling
Build toward:
- start time
- match duration
- halftime/break duration
- venue count
- minimum rest
- multi-day support

Scheduling priorities:
1. avoid back-to-back matches
2. protect minimum rest
3. allocate multiple venues
4. avoid obvious conflicts
5. wait for prerequisite knockout results
6. explain conflicts instead of silently producing bad schedules

### Match-day mode
Create a focused match-day surface:
- 当前比赛
- 主队 / 比分 / 客队
- 大尺寸比分操作
- 黄牌 / 红牌 / 结束比赛
- 下一场比赛
- 时间 / 场地 / 对阵

This view should be usable one-handed on a phone at the sideline.

### Data safety
- auto-save meaningful changes
- visible “已保存” feedback
- restore after refresh/reopen
- confirmation for destructive actions
- preserve existing results against accidental regeneration
- allow correction of finished matches with warning
- introduce undo where practical

### Standings and qualification
Scores should automatically update:
- 场次
- 胜 / 平 / 负
- 进球 / 失球 / 净胜球
- 积分
- 排名
- 晋级关系

Tie-break logic must be explainable to the user.

### Team entry
Preserve individual fields but add bulk paste:
one team name per line -> automatically populate teams.

Excel import can come later.

### Backup language
Keep underlying JSON if useful, but user-facing actions should be:
- 备份赛事
- 恢复赛事

### Public viewing
Later phase:
admin page can edit; public page is read-only.
Public page should expose:
- 赛事信息
- 赛程
- 比分
- 积分
- 晋级
- 结果

### Sharing
Later phase:
generate SAGI-styled share images for:
- 今日赛程
- 单场结果
- 积分榜
- 淘汰赛对阵
- 冠军结果

## Definition of done
A feature is not done unless:
- existing core behavior still works
- mobile use is comfortable
- data survives refresh/reopen
- score/standings/qualification are correct
- destructive operations are protected
- primary UI is understandable Chinese
- no placeholder/unfinished copy remains
- no obvious console/runtime error remains

When only code is committed but production is not verified, explicitly report:
“代码已提交，线上部署尚未验证。”
