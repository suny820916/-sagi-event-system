from __future__ import annotations

import json
import shutil
import traceback
import uuid
from pathlib import Path

from fastapi import BackgroundTasks, FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import FileResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles

from .config import settings
from .store import job_dir, load_job, patch_job, save_job, utc_now

APP_ROOT = Path(__file__).resolve().parents[2]
FRONTEND_DIR = APP_ROOT / "frontend"

app = FastAPI(
    title="SAGI MATCH INTELLIGENCE",
    version="1.0.0-alpha",
    description="萨吉体育基层足球 AI 比赛分析系统。",
)


def _run_analysis(job_id: str) -> None:
    try:
        from .analyzer import analyze_match

        job = load_job(job_id)
        if not job:
            return

        patch_job(job_id, status="running", progress=2.0, message="正在加载 AI 分析模型")

        def update(progress: float, message: str) -> None:
            patch_job(job_id, progress=round(progress, 1), message=message)

        output_dir = job_dir(job_id) / "artifacts"
        result = analyze_match(
            video_path=Path(job["video_path"]),
            output_dir=output_dir,
            home_team=job["home_team"],
            away_team=job["away_team"],
            progress=update,
        )

        patch_job(
            job_id,
            status="completed",
            progress=100.0,
            message="比赛分析完成",
            result=result,
        )
    except Exception as exc:
        traceback.print_exc()
        patch_job(
            job_id,
            status="failed",
            message=str(exc),
            error=type(exc).__name__,
        )


@app.get("/health")
def health() -> dict:
    return {
        "ok": True,
        "service": "SAGI 比赛智能分析",
        "version": "1.0.0-alpha",
        "device": settings.device,
        "model": settings.model,
    }


@app.post("/api/v1/jobs", status_code=202)
async def create_job(
    background_tasks: BackgroundTasks,
    video: UploadFile = File(...),
    home_team: str = Form("主队"),
    away_team: str = Form("客队"),
    match_format: str = Form("7v7"),
) -> dict:
    suffix = Path(video.filename or "match.mp4").suffix.lower()
    if suffix not in {".mp4", ".mov", ".mkv", ".avi", ".m4v"}:
        raise HTTPException(status_code=400, detail="不支持这个视频格式，请上传 MP4、MOV、MKV、AVI 或 M4V。")

    job_id = uuid.uuid4().hex[:12]
    directory = job_dir(job_id)
    input_path = directory / f"input{suffix}"

    max_bytes = settings.max_upload_mb * 1024 * 1024
    written = 0
    try:
        with input_path.open("wb") as target:
            while True:
                chunk = await video.read(1024 * 1024)
                if not chunk:
                    break
                written += len(chunk)
                if written > max_bytes:
                    target.close()
                    input_path.unlink(missing_ok=True)
                    raise HTTPException(
                        status_code=413,
                        detail=f"视频超过最大上传限制：{settings.max_upload_mb} MB。",
                    )
                target.write(chunk)
    finally:
        await video.close()

    payload = {
        "job_id": job_id,
        "status": "queued",
        "progress": 0.0,
        "message": "等待 AI 分析",
        "home_team": home_team.strip() or "主队",
        "away_team": away_team.strip() or "客队",
        "match_format": match_format,
        "filename": video.filename,
        "video_path": str(input_path.resolve()),
        "size_bytes": written,
        "created_at": utc_now(),
        "updated_at": utc_now(),
    }
    save_job(job_id, payload)
    background_tasks.add_task(_run_analysis, job_id)

    return {
        "job_id": job_id,
        "status": "queued",
        "poll": f"/api/v1/jobs/{job_id}",
    }


@app.get("/api/v1/jobs/{job_id}")
def get_job(job_id: str) -> dict:
    job = load_job(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="没有找到这个分析任务。")
    public = dict(job)
    public.pop("video_path", None)
    return public


@app.get("/api/v1/jobs/{job_id}/result")
def get_result(job_id: str) -> dict:
    job = load_job(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found.")
    result_path = job_dir(job_id) / "artifacts" / "result.json"
    if not result_path.exists():
        raise HTTPException(status_code=409, detail="分析结果还没有生成完成。")
    return json.loads(result_path.read_text(encoding="utf-8"))


@app.get("/api/v1/jobs/{job_id}/artifacts/{filename}")
def get_artifact(job_id: str, filename: str) -> FileResponse:
    safe_name = Path(filename).name
    if safe_name != filename:
        raise HTTPException(status_code=400, detail="文件名称无效。")
    path = job_dir(job_id) / "artifacts" / safe_name
    if not path.exists() or not path.is_file():
        raise HTTPException(status_code=404, detail="没有找到这个分析文件。")
    return FileResponse(path)


@app.delete("/api/v1/jobs/{job_id}", status_code=204)
def delete_job(job_id: str) -> None:
    directory = settings.data_dir / "jobs" / job_id
    if not directory.exists():
        raise HTTPException(status_code=404, detail="Job not found.")
    shutil.rmtree(directory)


if FRONTEND_DIR.exists():
    app.mount("/app", StaticFiles(directory=str(FRONTEND_DIR), html=True), name="frontend")


@app.get("/", include_in_schema=False)
def root() -> RedirectResponse:
    return RedirectResponse("/app/")
