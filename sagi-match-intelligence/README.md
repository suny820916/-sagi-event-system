# SAGI 比赛智能分析 V1.0 · 测试版

**萨吉体育 AI 足球比赛分析系统**

目标很简单：

> 上传一场真实比赛视频，系统自动识别球员和足球，追踪球员移动，尝试区分双方球队，估算控球，并生成热区与分析视频。

## V1.0 现在能做什么

- 上传整场比赛视频
- 自动识别球员和足球
- 自动追踪场上球员
- 根据球衣颜色尝试区分两支球队
- 根据足球与球员距离估算控球
- 记录球员移动位置
- 生成两队活动热区
- 生成带球员追踪编号的分析视频
- 手机浏览器直接上传、查看进度和结果
- 提供接口，后续可接 SAGI FOOTBALL OS 其他模块

## 目前还没有做到什么

V1.0 **不会假装已经拥有职业级精准数据**。

目前暂不提供：

- 精准识别每名球员真实姓名和号码
- 精准传球次数与成功率
- 精准抢断、助攻、越位
- xG 预期进球
- 职业级跑动距离与速度
- 完整 AI 教练战术结论

这些能力会在球场标定、球员身份确认和专用模型完善后逐步加入。

## 系统结构

```
手机 / 电脑操作界面
        ↓
比赛上传接口
        ↓
AI 分析任务
        ↓
球员与足球识别
        ↓
球员持续追踪
        ↓
球衣颜色分队
        ↓
控球估算
        ↓
移动轨迹 / 热区
        ↓
分析视频 + 数据结果
```

## 手机端使用流程

1. 输入主队名称
2. 输入客队名称
3. 选择六人制 / 七人制 / 九人制 / 十一人制
4. 选择比赛视频
5. 点击“开始 AI 分析”
6. 等待分析完成
7. 查看双方估算控球率
8. 查看球员追踪数量
9. 查看双方活动热区
10. 播放 AI 分析视频

## Docker 运行

```bash
cd sagi-match-intelligence
docker build -t sagi-match-intelligence .
docker run --rm -p 8000:8000 -v "$PWD/data:/app/data" sagi-match-intelligence
```

浏览器打开：

```
http://localhost:8000
```

## 本地运行

建议使用 Python 3.11。

```bash
cd sagi-match-intelligence
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn backend.app.main:app --reload --port 8000
```

第一次分析时，如果本地没有 AI 模型，系统会自动获取配置的 YOLO 模型。

## 主要接口

- `GET /health`：查看系统是否正常
- `POST /api/v1/jobs`：上传比赛并创建分析任务
- `GET /api/v1/jobs/{job_id}`：查看分析进度
- `GET /api/v1/jobs/{job_id}/result`：读取分析结果
- `GET /api/v1/jobs/{job_id}/artifacts/{filename}`：读取分析视频或热区图片

> 接口路径保持英文，是为了代码与服务器兼容；普通使用时不需要操作这些接口。

## 重要设置

- `SAGI_MODEL=yolo11n.pt`：AI 模型
- `SAGI_DEVICE=cpu`：使用 CPU
- `SAGI_DEVICE=0`：使用第一块 NVIDIA GPU
- `SAGI_ANALYSIS_FPS=3`：每秒分析的画面数量
- `SAGI_MAX_UPLOAD_MB=4096`：最大上传文件大小

正式分析整场比赛，后续建议把 AI 运算放到 GPU 服务器；手机只负责上传和查看结果。

## 下一版 V1.1

重点进入 **真实球场标定**：

- 手动/半自动球场标定
- 视频画面映射到真实 2D 足球场
- 球员真实场上坐标
- 球员号码人工确认
- 门将与裁判处理
- 接入 SAGI PLAYER ID
- 为跑动距离、速度、平均站位、防线高度做准备

---

**SAGI SPORTS · 记录平凡人的足球梦**
