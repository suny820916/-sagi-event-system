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
from yt_dlp.utils import DownloadError

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
pair_codes = {}
pair_lock = Lock()
worker_presence = {"last_seen": 0, "worker_id": ""}

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

def worker_token():
    if not SERVER_SECRET:
        return ""
    return hmac.new(
        SERVER_SECRET.encode("utf-8"),
        b"sagi-content-os-instagram-worker-v1",
        hashlib.sha256,
    ).hexdigest()

def worker_authorized():
    token = worker_token()
    if not token:
        return False
    header = request.headers.get("Authorization", "")
    supplied = header[7:] if header.startswith("Bearer ") else ""
    return bool(supplied) and hmac.compare_digest(supplied, token)

def touch_worker(worker_id=""):
    worker_presence["last_seen"] = time.time()
    if worker_id:
        worker_presence["worker_id"] = worker_id[:80]

def worker_online():
    return (time.time() - float(worker_presence.get("last_seen") or 0)) < 45

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
        "errorCode": job.get("errorCode", ""),
        "strategy": job.get("strategy", ""),
        "worker": job.get("worker", ""),
        "size": job.get("size", 0),
    }
    if job["status"] == "ready":
        data["downloadUrl"] = (
            request.host_url.rstrip("/")
            + f"/api/jobs/{job['id']}/file?key={job['download_key']}"
        )
    return data

def _looks_like_429(message):
    text = (message or "").lower()
    return "429" in text or "too many requests" in text or "rate-limit" in text or "rate limit" in text

def _download_with_strategy(url, work, strategy):
    outtmpl = str(Path(work) / "%(title).80s_%(id)s.%(ext)s")
    common = {
        "format": "best[ext=mp4]/best",
        "outtmpl": outtmpl,
        "noplaylist": True,
        "quiet": True,
        "no_warnings": True,
        "restrictfilenames": True,
        "retries": 2,
        "fragment_retries": 2,
        "socket_timeout": 20,
        "sleep_interval_requests": 1,
        "max_sleep_interval": 3,
        "max_filesize": MAX_FILE_MB * 1024 * 1024,
    }

    if strategy == "ios":
        common["extractor_args"] = {"instagram": {"app_id": ["ios"]}}
        common["http_headers"] = {
            "User-Agent": "Instagram 402.0.0.0.0 iOS (18_5; iPhone17,1; en_US)",
            "Accept-Language": "en-US,en;q=0.9",
        }
    elif strategy == "android":
        common["extractor_args"] = {"instagram": {"app_id": ["567067343352427"]}}
        common["http_headers"] = {
            "User-Agent": "Instagram 435.0.0.37.76 Android (35/15; 480dpi; 1080x2400; Google; Pixel 9; tokay; en_US; 700000000)",
            "Accept-Language": "en-US,en;q=0.9",
        }
    else:
        common["extractor_args"] = {"instagram": {"app_id": ["web"]}}
        common["http_headers"] = {
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 Version/18.5 Mobile/15E148 Safari/604.1",
            "Accept-Language": "en-US,en;q=0.9",
        }

    with yt_dlp.YoutubeDL(common) as ydl:
        return ydl.extract_info(url, download=True)

def run_download(job_id, url, wanted_name):
    with jobs_lock:
        job = jobs.get(job_id)
        if not job:
            return
        job["status"] = "downloading"
        job["updated_at"] = iso()
        job["strategy"] = "web"

    work = tempfile.mkdtemp(prefix=f"sagi_cloud_{job_id}_")
    strategies = ["web", "ios", "android"]
    info = None
    errors = []
    saw_429 = False

    try:
        for strategy in strategies:
            with jobs_lock:
                job = jobs.get(job_id)
                if job:
                    job["strategy"] = strategy
                    job["updated_at"] = iso()

            try:
                info = _download_with_strategy(url, work, strategy)
                if info:
                    break
            except DownloadError as e:
                msg = str(e)
                errors.append(f"{strategy}: {msg}")
                if _looks_like_429(msg):
                    saw_429 = True
                # clear partial files before trying the next extractor profile
                for p in Path(work).iterdir():
                    if p.is_file():
                        try:
                            p.unlink()
                        except Exception:
                            pass
                time.sleep(2 if saw_429 else 1)
            except Exception as e:
                msg = str(e)
                errors.append(f"{strategy}: {msg}")
                if _looks_like_429(msg):
                    saw_429 = True
                time.sleep(1)

        if not info:
            if saw_429:
                raise RuntimeError(
                    "INSTAGRAM_RATE_LIMIT: Instagram rejected the cloud outbound IP with HTTP 429. "
                    "The SAGI cloud service is online, but this Render IP is temporarily rate-limited."
                )
            raise RuntimeError("Instagram extraction failed: " + " | ".join(errors[-2:]))

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
                "error": "",
            })
    except Exception as e:
        shutil.rmtree(work, ignore_errors=True)
        msg = str(e)
        code = "instagram_rate_limit" if "INSTAGRAM_RATE_LIMIT" in msg else "instagram_extract_failed"
        with jobs_lock:
            job = jobs.get(job_id)
            if job:
                job.update({
                    "status": "failed",
                    "updated_at": iso(),
                    "error": msg[:700],
                    "errorCode": code,
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
        "version": "1.2.0",
        "instagram": True,
        "hybridWorker": True,
        "workerOnline": worker_online(),
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
        "version": "1.2.0",
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
        "status": "waiting_worker",
        "created_at": iso(),
        "updated_at": iso(),
        "title": name,
        "source_url": url,
        "requested_name": name,
        "error": "",
        "errorCode": "",
        "size": 0,
        "worker": "",
        "download_key": secrets.token_urlsafe(18),
        "path": "",
        "workdir": "",
        "filename": "",
    }
    with jobs_lock:
        jobs[job_id] = job

    return jsonify({
        "ok": True,
        "job": public_job(job),
        "workerOnline": worker_online()
    }), 202


@app.post("/api/worker/pair/start")
def worker_pair_start():
    if not authorized():
        return jsonify({"ok": False, "error": "Unauthorized"}), 401
    code = f"{secrets.randbelow(1000000):06d}"
    with pair_lock:
        pair_codes.clear()
        pair_codes[code] = time.time() + 600
    return jsonify({"ok": True, "code": code, "expiresIn": 600})

@app.post("/api/worker/pair/claim")
def worker_pair_claim():
    data = request.get_json(silent=True) or {}
    code = str(data.get("code") or "").strip()
    worker_id = str(data.get("workerId") or "").strip()[:80]
    if not code:
        return jsonify({"ok": False, "error": "Pair code required"}), 400
    with pair_lock:
        expires = pair_codes.get(code)
        if not expires or expires < time.time():
            pair_codes.pop(code, None)
            return jsonify({"ok": False, "error": "Pair code invalid or expired"}), 403
        pair_codes.pop(code, None)
    token = worker_token()
    if not token:
        return jsonify({"ok": False, "error": "Worker secret unavailable"}), 503
    touch_worker(worker_id)
    return jsonify({
        "ok": True,
        "token": token,
        "cloud": request.host_url.rstrip("/"),
        "workerId": worker_id,
    })

@app.get("/api/worker/status")
def worker_status():
    if not authorized():
        return jsonify({"ok": False, "error": "Unauthorized"}), 401
    age = None
    if worker_presence["last_seen"]:
        age = max(0, int(time.time() - worker_presence["last_seen"]))
    return jsonify({
        "ok": True,
        "online": worker_online(),
        "lastSeenSeconds": age,
        "workerId": worker_presence.get("worker_id") or "",
    })

@app.get("/api/worker/jobs/next")
def worker_job_next():
    if not worker_authorized():
        return jsonify({"ok": False, "error": "Unauthorized worker"}), 401
    worker_id = (request.headers.get("X-SAGI-Worker") or "SAGI-PC").strip()[:80]
    touch_worker(worker_id)
    chosen = None
    with jobs_lock:
        waiting = sorted(
            [j for j in jobs.values() if j.get("status") == "waiting_worker"],
            key=lambda x: x.get("created_at", "")
        )
        if waiting:
            chosen = waiting[0]
            chosen["status"] = "worker_downloading"
            chosen["worker"] = worker_id
            chosen["updated_at"] = iso()
    if not chosen:
        return jsonify({"ok": True, "job": None})
    return jsonify({
        "ok": True,
        "job": {
            "id": chosen["id"],
            "url": chosen["source_url"],
            "name": chosen["requested_name"],
        }
    })

@app.post("/api/worker/jobs/<job_id>/complete")
def worker_job_complete(job_id):
    if not worker_authorized():
        return jsonify({"ok": False, "error": "Unauthorized worker"}), 401
    worker_id = (request.headers.get("X-SAGI-Worker") or "SAGI-PC").strip()[:80]
    touch_worker(worker_id)
    upload = request.files.get("file")
    if not upload:
        return jsonify({"ok": False, "error": "file is required"}), 400

    with jobs_lock:
        job = jobs.get(job_id)
        if not job:
            return jsonify({"ok": False, "error": "Job not found"}), 404

    work = tempfile.mkdtemp(prefix=f"sagi_worker_{job_id}_")
    filename = safe_name(request.form.get("name") or job.get("requested_name") or "SAGI_INS_VIDEO.mp4")
    if "." not in filename:
        filename += ".mp4"
    path = Path(work) / filename
    upload.save(path)
    size = path.stat().st_size
    if size > MAX_FILE_MB * 1024 * 1024:
        shutil.rmtree(work, ignore_errors=True)
        return jsonify({"ok": False, "error": f"File exceeds {MAX_FILE_MB}MB"}), 413

    with jobs_lock:
        job = jobs.get(job_id)
        if not job:
            shutil.rmtree(work, ignore_errors=True)
            return jsonify({"ok": False, "error": "Job expired"}), 410
        if job.get("workdir"):
            shutil.rmtree(job["workdir"], ignore_errors=True)
        job.update({
            "status": "ready",
            "updated_at": iso(),
            "path": str(path),
            "workdir": work,
            "filename": filename,
            "title": request.form.get("title") or filename,
            "size": size,
            "worker": worker_id,
            "error": "",
            "errorCode": "",
        })
    return jsonify({"ok": True, "job": public_job(job)})

@app.post("/api/worker/jobs/<job_id>/fail")
def worker_job_fail(job_id):
    if not worker_authorized():
        return jsonify({"ok": False, "error": "Unauthorized worker"}), 401
    worker_id = (request.headers.get("X-SAGI-Worker") or "SAGI-PC").strip()[:80]
    touch_worker(worker_id)
    data = request.get_json(silent=True) or {}
    msg = str(data.get("error") or "Worker download failed")[:700]
    with jobs_lock:
        job = jobs.get(job_id)
        if not job:
            return jsonify({"ok": False, "error": "Job not found"}), 404
        job.update({
            "status": "failed",
            "updated_at": iso(),
            "worker": worker_id,
            "error": msg,
            "errorCode": "worker_download_failed",
        })
    return jsonify({"ok": True})

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
