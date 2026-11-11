import json
import threading
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .config import settings

_lock = threading.Lock()


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def job_dir(job_id: str) -> Path:
    path = settings.data_dir / "jobs" / job_id
    path.mkdir(parents=True, exist_ok=True)
    return path


def job_file(job_id: str) -> Path:
    return job_dir(job_id) / "job.json"


def save_job(job_id: str, payload: dict[str, Any]) -> dict[str, Any]:
    with _lock:
        path = job_file(job_id)
        tmp = path.with_suffix(".tmp")
        tmp.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
        tmp.replace(path)
    return payload


def load_job(job_id: str) -> dict[str, Any] | None:
    path = job_file(job_id)
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def patch_job(job_id: str, **changes: Any) -> dict[str, Any]:
    with _lock:
        path = job_file(job_id)
        if not path.exists():
            raise FileNotFoundError(job_id)
        payload = json.loads(path.read_text(encoding="utf-8"))
        payload.update(changes)
        payload["updated_at"] = utc_now()
        tmp = path.with_suffix(".tmp")
        tmp.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
        tmp.replace(path)
    return payload
