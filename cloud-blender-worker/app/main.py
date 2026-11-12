from __future__ import annotations

import json
import os
import secrets
import subprocess
import time
import uuid
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Any

from fastapi import Depends, FastAPI, Header, HTTPException
from fastapi.responses import FileResponse, PlainTextResponse
from pydantic import BaseModel, Field

APP_VERSION = "1.0.0"
ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT / "engine" / "sagi_tactics_blender.py"
BENCHMARK = ROOT / "presets" / "benchmark_4231.json"
JOBS_DIR = Path(os.getenv("SAGI_JOBS_DIR", "/tmp/sagi_jobs"))
MAX_WORKERS = max(1, int(os.getenv("SAGI_MAX_WORKERS", "1")))
TIMEOUT = max(60, int(os.getenv("SAGI_RENDER_TIMEOUT_SEC", "1800")))
API_KEY = os.getenv("SAGI_API_KEY", "").strip()

JOBS_DIR.mkdir(parents=True, exist_ok=True)
EXECUTOR = ThreadPoolExecutor(max_workers=MAX_WORKERS, thread_name_prefix="sagi-blender")

app = FastAPI(
    title="SAGI TACTICS · CLOUD BLENDER WORKER",
    version=APP_VERSION,
    description="JSON tactical scene -> Blender headless -> iPhone-compatible MP4",
)

class RenderRequest(BaseModel):
    config: dict[str, Any] = Field(..., description="SAGI tactical scene JSON")


def auth(x_api_key: str | None = Header(default=None)) -> None:
    if API_KEY and not x_api_key:
        raise HTTPException(401, "Missing X-API-Key")
    if API_KEY and not secrets.compare_digest(x_api_key or "", API_KEY):
        raise HTTPException(403, "Invalid X-API-Key")


def status_path(job_id: str) -> Path:
    return JOBS_DIR / job_id / "status.json"


def read_status(job_id: str) -> dict[str, Any]:
    p = status_path(job_id)
    if not p.exists():
        raise HTTPException(404, "Job not found")
    return json.loads(p.read_text(encoding="utf-8"))


def write_status(job_id: str, **updates: Any) -> None:
    p = status_path(job_id)
    current: dict[str, Any] = {}
    if p.exists():
        try:
            current = json.loads(p.read_text(encoding="utf-8"))
        except Exception:
            current = {}
    current.update(updates)
    current["updated_at"] = time.time()
    tmp = p.with_suffix(".tmp")
    tmp.write_text(json.dumps(current, ensure_ascii=False, indent=2), encoding="utf-8")
    tmp.replace(p)


def safe_config(config: dict[str, Any]) -> dict[str, Any]:
    fps = int(config.get("fps", 24))
    duration = float(config.get("duration_sec", 12))
    res = config.get("resolution", [540, 960])
    if not 12 <= fps <= 60:
        raise HTTPException(400, "fps must be 12..60")
    if not 1 <= duration <= 180:
        raise HTTPException(400, "duration_sec must be 1..180")
    if not isinstance(res, list) or len(res) != 2:
        raise HTTPException(400, "resolution must be [width,height]")
    if int(res[0]) > 1080 or int(res[1]) > 1920:
        raise HTTPException(400, "V1 max resolution is 1080x1920")
    return config


def enqueue(config: dict[str, Any]) -> dict[str, Any]:
    config = safe_config(config)
    job_id = uuid.uuid4().hex[:12]
    job_dir = JOBS_DIR / job_id
    job_dir.mkdir(parents=True, exist_ok=False)
    (job_dir / "config.json").write_text(
        json.dumps(config, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    write_status(
        job_id,
        job_id=job_id,
        status="queued",
        created_at=time.time(),
        progress=0,
    )
    EXECUTOR.submit(run_job, job_id)
    return read_status(job_id)


def run_job(job_id: str) -> None:
    job_dir = JOBS_DIR / job_id
    cfg = job_dir / "config.json"
    log = job_dir / "blender.log"
    raw = job_dir / "render_raw.mp4"
    final = job_dir / "render.mp4"

    try:
        write_status(job_id, status="rendering", progress=10)

        cmd = [
            "blender",
            "--background",
            "--python",
            str(ENGINE),
            "--",
            str(cfg),
            str(job_dir),
        ]
        with log.open("w", encoding="utf-8") as f:
            proc = subprocess.run(
                cmd,
                stdout=f,
                stderr=subprocess.STDOUT,
                timeout=TIMEOUT,
            )

        if proc.returncode != 0:
            raise RuntimeError(f"Blender exited with code {proc.returncode}")
        if not raw.exists():
            raise RuntimeError("Blender completed but render_raw.mp4 is missing")

        write_status(job_id, status="transcoding", progress=85)

        ffmpeg = [
            "ffmpeg", "-y", "-loglevel", "error",
            "-i", str(raw),
            "-f", "lavfi",
            "-i", "anullsrc=channel_layout=stereo:sample_rate=44100",
            "-map", "0:v:0",
            "-map", "1:a:0",
            "-c:v", "libx264",
            "-profile:v", "baseline",
            "-level", "3.1",
            "-pix_fmt", "yuv420p",
            "-preset", "veryfast",
            "-crf", "23",
            "-c:a", "aac",
            "-b:a", "64k",
            "-shortest",
            "-movflags", "+faststart",
            str(final),
        ]
        subprocess.run(ffmpeg, check=True, timeout=300)

        write_status(
            job_id,
            status="done",
            progress=100,
            video=f"/jobs/{job_id}/video",
            blend=f"/jobs/{job_id}/blend",
            log=f"/jobs/{job_id}/log",
            size_bytes=final.stat().st_size,
        )

    except subprocess.TimeoutExpired:
        write_status(
            job_id,
            status="failed",
            progress=0,
            error=f"Render timed out after {TIMEOUT}s",
        )
    except Exception as e:
        write_status(
            job_id,
            status="failed",
            progress=0,
            error=str(e),
            log=f"/jobs/{job_id}/log",
        )


@app.get("/health")
def health() -> dict[str, Any]:
    blender_version = "unknown"
    try:
        out = subprocess.check_output(
            ["blender", "--version"],
            text=True,
            timeout=5,
        ).splitlines()[0]
        blender_version = out.strip()
    except Exception:
        pass

    return {
        "ok": True,
        "service": "SAGI TACTICS · CLOUD BLENDER WORKER",
        "version": APP_VERSION,
        "blender": blender_version,
        "max_workers": MAX_WORKERS,
    }


@app.post("/benchmark", dependencies=[Depends(auth)])
def benchmark() -> dict[str, Any]:
    config = json.loads(BENCHMARK.read_text(encoding="utf-8"))
    return enqueue(config)


@app.post("/jobs", dependencies=[Depends(auth)])
def create_job(req: RenderRequest) -> dict[str, Any]:
    return enqueue(req.config)


@app.get("/jobs/{job_id}", dependencies=[Depends(auth)])
def get_job(job_id: str) -> dict[str, Any]:
    return read_status(job_id)


@app.get("/jobs/{job_id}/video", dependencies=[Depends(auth)])
def get_video(job_id: str):
    p = JOBS_DIR / job_id / "render.mp4"
    if not p.exists():
        raise HTTPException(404, "Video is not ready")
    return FileResponse(
        p,
        media_type="video/mp4",
        filename=f"sagi_tactics_{job_id}.mp4",
    )


@app.get("/jobs/{job_id}/blend", dependencies=[Depends(auth)])
def get_blend(job_id: str):
    p = JOBS_DIR / job_id / "scene.blend"
    if not p.exists():
        raise HTTPException(404, "Blend file is not ready")
    return FileResponse(
        p,
        media_type="application/octet-stream",
        filename=f"sagi_tactics_{job_id}.blend",
    )


@app.get("/jobs/{job_id}/log", dependencies=[Depends(auth)])
def get_log(job_id: str):
    p = JOBS_DIR / job_id / "blender.log"
    if not p.exists():
        raise HTTPException(404, "Log is not ready")
    return PlainTextResponse(
        p.read_text(encoding="utf-8", errors="replace")[-50000:]
    )
