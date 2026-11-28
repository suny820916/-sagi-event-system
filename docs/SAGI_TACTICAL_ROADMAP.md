# SAGI 战术动画工厂路线图

[项目章程](SAGI_TACTICAL_ANIMATION_CHARTER.md) · [架构](SAGI_TACTICAL_ARCHITECTURE.md)

1. **现状复验**。在独立生产分支复验 Blender 入口和 CI 证据，建立技术 A、真实性 B、Teactics 视觉 C 三道独立验收。历史 PASS 仅适用于对应归档。
2. **动作与触球**。优先复用现有引擎制作 5–10 秒接球、传球、跑动、转身、防守、射门、球脚接触、镜头、空间、连续动作测试。先验证减速、支撑脚、触球与出球时序，再渲染整片。
3. **REAL MATCH GOLDEN SAMPLE 001**。取得比赛片段，逐帧确认动作链，人工确认后生成事件 JSON 和导演数据，调用现有 Worker。最终保存来源、关键帧、工程、MP4 以及三道 QA。未知触球、轨迹和跑位保持未确认。
4. **统一生产**。从通过回归的样本逐步提取可复用的动作、球和镜头能力，再评估视频识别与追踪。

## 001 候选证据

[FIFA 官方赛报与集锦](https://www.fifa.com/en/tournaments/mens/u17worldcup/qatar-2026/articles/matchday-9-round-up-doha) 记录 2026 FIFA U-17 世界杯 L 组哥伦比亚 0–1 塞尔维亚，Nebojsa Grujic 第 72 分钟进球，Ognjen Matanovic 将进入禁区的球凌空回做。逐帧比赛素材、完整触球链、跑位、坐标与渲染仍待验证。
