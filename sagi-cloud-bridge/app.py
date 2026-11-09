from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
from urllib.parse import urlparse
from pathlib import Path
from threading import Thread, Lock
from datetime import datetime, timedelta, timezone
import tempfile
import shutil
import secrets
import hashlib
import hmac
import os
import time
import yt_dlp

app = Flask(__name__)

ALLOWED_ORIGIN = (os.getenv("SAGI_ALLOWED_ORIGIN") or "https://suny820916.github.io").rstrip("/")
SERVER_SECRET = (os.getenv("SAGI_SERVER_SECRET") or os.getenv("SAGI_BRIDGE_TOKEN") or "").strip()
PORT = int(os.getenv("PORT") or "10000")
MAX_FILE_MB = int(os.getenv("SAGI_MAX_FILE_MB") or "300")
JOB_TTL_MIN = int(os.getenv("SAGI_JOB_TTL_MIN") or "30")
RATE_LIMIT_PER_HOUR = int(os.getenv("SAGI_RATE_LIMIT_PER_HOUR") or "20")

CORS(app, resources={r"/api/*": {"origins": [ALLOWED_ORIGIN]}, r"/health": {"origins": [ALLOWED_ORIGIN]}, r"/": {"origins": [ALLOWED_ORIGIN]}})

jobs = {}
jobs_lock = Lock()
rate_hits = {}
rate_lock = Lock()

def now():
    return datetime.now(timezone.utc)

def iso(dt=None):
    return (dt or now()).isoformat()

def client_token():
    if not SERVER_SECRET:
        return ""
    return hmac.new(
        SERVER_SECRET.encode("utf-8"),
        b"sagi-content-os-instagram-cloud-client-v1",
        hashlib.sha256,
    ).hexdigest()

def origin_allowed():
    origin = (request.headers.get("Origin") or "").rstrip("/")
    return origin == ALLOWED_ORIGIN

def authorized():
    token = client_token()
    if not token:
        return False
    header = request.headers.get("Authorization", "")
    supplied = header[7:] if header.startswith("Bearer ") else ""
    return bool(supplied) and hmac.compare_digest(supplied, token)

def rate_allowed():
    key = request.headers.get("X-Forwarded-For", request.remote_addr or "unknown").split(",")[0].strip()
    cutoff = time.time() - 3600
    with rate_lock:
        arr = [t for t in rate_hits.get(key, []) if t >= cutoff]
        if len(arr) >= RATE_LIMIT_PER_HOUR:
            rate_hits[key] = arr
            return False
        arr.append(time.time())
        rate_hits[key] = arr
    return True

def allowed_instagram(url):
    try:
        u = urlparse(url)
        if u.scheme not in ("http", "https"):
            return False
        host = (u.hostname or "").lower().strip(".")
        return host == "instagram.com" or host.endswith(".instagram.com")
    except Exception:
        return False

def safe_name(name):
    raw = (name or "SAGI_INS_VIDEO").strip()
    clean = "".join(c for c in raw if c not in '\\/:*?"<>|').strip()
    return (clean or "SAGI_INS_VIDEO")[:100]

def public_job(job):
    data = {
        "id": job["id"],
        "status": job["status"],
        "createdAt": job["created_at"],
        "updatedAt": job["updated_at"],
        "title": job.get("title", ""),
        "error": job.get("error", ""),
        "size": job.get("size", 0),
    }
    if job["status"] == "ready":
        data["downloadUrl"] = (
            request.host_url.rstrip("/")
            + f"/api/jobs/{job['id']}/file?key={job['download_key']}"
        )
    return data

def run_download(job_id, url, wanted_name):
    with jobs_lock:
        job = jobs.get(job_id)
        if not job:
            return
        job["status"] = "downloading"
        job["updated_at"] = iso()

    work = tempfile.mkdtemp(prefix=f"sagi_cloud_{job_id}_")
    outtmpl = str(Path(work) / "%(title).80s_%(id)s.%(ext)s")
    opts = {
        "format": "best[ext=mp4]/best",
        "outtmpl": outtmpl,
        "noplaylist": True,
        "quiet": True,
        "no_warnings": True,
        "restrictfilenames": True,
        "merge_output_format": "mp4",
        "retries": 3,
        "fragment_retries": 3,
        "max_filesize": MAX_FILE_MB * 1024 * 1024,
        "socket_timeout": 20,
    }

    try:
        with yt_dlp.YoutubeDL(opts) as ydl:
            info = ydl.extract_info(url, download=True)

        files = [
            p for p in Path(work).iterdir()
            if p.is_file() and not p.name.endswith((".part", ".ytdl", ".json"))
        ]
        if not files:
            raise RuntimeError("Instagram 未返回可下载的视频文件")

        media = max(files, key=lambda p: p.stat().st_size)
        size = media.stat().st_size
        if size > MAX_FILE_MB * 1024 * 1024:
            raise RuntimeError(f"视频超过云端限制 {MAX_FILE_MB}MB")

        ext = media.suffix or ".mp4"
        desired = safe_name(wanted_name)
        if not desired.lower().endswith(ext.lower()):
            desired += ext

        with jobs_lock:
            job = jobs[job_id]
            job.update({
                "status": "ready",
                "updated_at": iso(),
                "path": str(media),
                "workdir": work,
                "filename": desired,
                "title": info.get("title") or desired,
                "size": size,
            })
    except Exception as e:
        shutil.rmtree(work, ignore_errors=True)
        with jobs_lock:
            job = jobs.get(job_id)
            if job:
                job.update({
                    "status": "failed",
                    "updated_at": iso(),
                    "error": str(e)[:500],
                })

def cleanup_loop():
    while True:
        cutoff = now() - timedelta(minutes=JOB_TTL_MIN)
        remove = []
        with jobs_lock:
            for job_id, job in jobs.items():
                try:
                    created = datetime.fromisoformat(job["created_at"])
                except Exception:
                    created = now()
                if created < cutoff:
                    remove.append(job_id)
            for job_id in remove:
                job = jobs.pop(job_id, None)
                if job and job.get("workdir"):
                    shutil.rmtree(job["workdir"], ignore_errors=True)
        time.sleep(60)

Thread(target=cleanup_loop, daemon=True).start()

@app.after_request
def security_headers(resp):
    resp.headers["Cache-Control"] = "no-store"
    resp.headers["X-Content-Type-Options"] = "nosniff"
    return resp

@app.get("/")
@app.get("/health")
def health():
    return jsonify({
        "ok": True,
        "service": "SAGI CLOUD BRIDGE",
        "version": "1.1.0",
        "instagram": True,
        "activation": True,
        "maxFileMB": MAX_FILE_MB,
        "jobTTLMinutes": JOB_TTL_MIN,
        "configured": bool(SERVER_SECRET),
    })

@app.post("/api/activate")
def activate():
    if not origin_allowed():
        return jsonify({"ok": False, "error": "Origin not allowed"}), 403
    token = client_token()
    if not token:
        return jsonify({"ok": False, "error": "Cloud service secret is not configured"}), 503
    return jsonify({
        "ok": True,
        "service": "SAGI CLOUD BRIDGE",
        "token": token,
        "version": "1.1.0",
    })

@app.post("/api/jobs")
def create_job():
    if not authorized():
        return jsonify({"ok": False, "error": "Unauthorized"}), 401
    if not rate_allowed():
        return jsonify({"ok": False, "error": "Hourly download limit reached"}), 429

    data = request.get_json(silent=True) or {}
    url = (data.get("url") or "").strip()
    name = safe_name(data.get("name") or "SAGI_INS_VIDEO")

    if not allowed_instagram(url):
        return jsonify({"ok": False, "error": "Only Instagram URLs are enabled."}), 400

    job_id = secrets.token_urlsafe(9)
    job = {
        "id": job_id,
        "status": "queued",
        "created_at": iso(),
        "updated_at": iso(),
        "title": name,
        "error": "",
        "size": 0,
        "download_key": secrets.token_urlsafe(18),
        "path": "",
        "workdir": "",
        "filename": "",
    }
    with jobs_lock:
        jobs[job_id] = job

    Thread(target=run_download, args=(job_id, url, name), daemon=True).start()
    return jsonify({"ok": True, "job": public_job(job)}), 202

@app.get("/api/jobs/<job_id>")
def job_status(job_id):
    if not authorized():
        return jsonify({"ok": False, "error": "Unauthorized"}), 401
    with jobs_lock:
        job = jobs.get(job_id)
        if not job:
            return jsonify({"ok": False, "error": "Job not found"}), 404
        return jsonify({"ok": True, "job": public_job(job)})

@app.get("/api/jobs/<job_id>/file")
def job_file(job_id):
    key = request.args.get("key") or ""
    with jobs_lock:
        job = jobs.get(job_id)
        if not job:
            return jsonify({"ok": False, "error": "Job not found"}), 404
        if key != job.get("download_key"):
            return jsonify({"ok": False, "error": "Invalid download key"}), 403
        if job.get("status") != "ready" or not job.get("path"):
            return jsonify({"ok": False, "error": "File not ready"}), 409
        path = job["path"]
        filename = job["filename"]

    if not Path(path).exists():
        return jsonify({"ok": False, "error": "File expired"}), 410
    return send_file(path, as_attachment=True, download_name=filename, conditional=True)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=PORT, threaded=True)
