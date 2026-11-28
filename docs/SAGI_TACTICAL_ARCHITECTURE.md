# SAGI 战术动画工厂架构

[项目章程](SAGI_TACTICAL_ANIMATION_CHARTER.md) · [路线图](SAGI_TACTICAL_ROADMAP.md)

## 已核实的生产入口

```text
战术场景 JSON → FastAPI 入队 → Blender Headless → 场景工程与 PNG 帧
                                                 ↓
                                              FFmpeg → MP4
```

- [服务入口](../cloud-blender-worker/app/main.py) 接收配置，维护任务状态，由 run_job 调用 [Blender 引擎](../cloud-blender-worker/engine/sagi_tactics_blender.py)，随后用 FFmpeg 编码；任务接口提供视频、工程和日志。
- [容器配置](../cloud-blender-worker/Dockerfile) 安装 Blender 与 FFmpeg，启动 Uvicorn。[Worker 说明](../cloud-blender-worker/README.md) 描述接口与基准任务。
- [穆里尼奥 70 秒独立审计](../cloud-blender-worker/qa/audit_mourinho_70s.py) 检查报告、时长、关键帧、解码状态和投影采样。三段亮度是诊断指标，不能单独证明裁切或视觉通过。

## 能力边界

V52 历史归档可见 Blender 工程、预设、MP4、关键帧及历史 QA。麦孔本地 PowerShell 样片属于独立验证产物，不能证明本分支 Blender 链在当前 HEAD 已重新运行。Camera DNA、Relation Camera、九层导演、程序化动作以及 Frame Safety 的当前调用深度仍须逐项验证。当前没有可复核证据证明统一真实比赛输入、骨骼动作库、独立触球验收或 99% Teactics 视觉验收已完成。

真实事件 JSON → 战术关系与导演方案 → 动作、球和镜头 → 现有 Worker 是后续收敛方向。保留现有接口，先追踪并复用当前实现。
