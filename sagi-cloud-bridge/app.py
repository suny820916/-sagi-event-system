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
import subprocess
import json
import re
import gc
import requests
import yt_dlp
from yt_dlp.utils import DownloadError
from faster_whisper import WhisperModel
import imageio_ffmpeg

app = Flask(__name__)

ALLOWED_ORIGIN = (os.getenv("SAGI_ALLOWED_ORIGIN") or "https://suny820916.github.io").rstrip("/")
SERVER_SECRET = (os.getenv("SAGI_SERVER_SECRET") or os.getenv("SAGI_BRIDGE_TOKEN") or "").strip()
PORT = int(os.getenv("PORT") or "10000")
DEPLOY_REVISION = "2026-11-10-v1710-cloud-download"
APP_VERSION = "1.7.1"
MAX_FILE_MB = int(os.getenv("SAGI_MAX_FILE_MB") or "300")
JOB_TTL_MIN = int(os.getenv("SAGI_JOB_TTL_MIN") or "30")
RATE_LIMIT_PER_HOUR = int(os.getenv("SAGI_RATE_LIMIT_PER_HOUR") or "20")
CAPTION_RATE_LIMIT_PER_HOUR = int(os.getenv("SAGI_CAPTION_RATE_LIMIT_PER_HOUR") or "180")
caption_rate_hits = {}
caption_rate_lock = Lock()
COBALT_HOSTPORT = (os.getenv("SAGI_COBALT_HOSTPORT") or "").strip()
INSTAGRAM_PROXY = (os.getenv("SAGI_INSTAGRAM_PROXY") or "").strip()

CORS(app, resources={r"/api/*": {"origins": [ALLOWED_ORIGIN]}, r"/health": {"origins": [ALLOWED_ORIGIN]}, r"/": {"origins": [ALLOWED_ORIGIN]}})

jobs = {}
jobs_lock = Lock()
rate_hits = {}
rate_lock = Lock()
pair_codes = {}
pair_lock = Lock()
worker_presence = {"last_seen": 0, "worker_id": ""}

CAPTION_MODEL_DIR = str(Path(__file__).resolve().parent / "model_cache" / "tiny")
caption_model = None
caption_model_error = ""
caption_model_lock = Lock()
caption_ready_at = 0.0
CAPTION_MAX_MB = int(os.getenv("SAGI_CAPTION_MAX_MB") or "16")
CAPTION_MEDIA_MAX_MB = int(os.getenv("SAGI_CAPTION_MEDIA_MAX_MB") or "180")
ELEVENLABS_API_KEY = (os.getenv("ELEVENLABS_API_KEY") or "").strip()
ELEVENLABS_MALE_VOICE_ID = (os.getenv("ELEVENLABS_MALE_VOICE_ID") or "").strip()
ELEVENLABS_FEMALE_VOICE_ID = (os.getenv("ELEVENLABS_FEMALE_VOICE_ID") or "").strip()
ELEVENLABS_BASE = "https://api.elevenlabs.io"
VOICE_SAMPLE_MAX_MB = int(os.getenv("SAGI_VOICE_SAMPLE_MAX_MB") or "25")
RENDER_MAX_MB = int(os.getenv("SAGI_RENDER_MAX_MB") or "300")
FONT_URL = os.getenv("SAGI_CJK_FONT_URL") or "https://raw.githubusercontent.com/notofonts/noto-cjk/main/Sans/OTF/SimplifiedChinese/NotoSansCJKsc-Regular.otf"
FONT_DIR = Path(tempfile.gettempdir()) / "sagi_fonts"
FONT_PATH = FONT_DIR / "NotoSansCJKsc-Regular.otf"

render_jobs = {}
render_jobs_lock = Lock()
render_slot = Lock()
# All memory-heavy work shares one slot. This prevents Whisper + FFmpeg from
# peaking at the same time on small Render instances.
heavy_slot = Lock()
FFMPEG_THREADS = max(1, min(2, int(os.getenv("SAGI_FFMPEG_THREADS") or "1")))
STATE_DIR = Path(os.getenv("SAGI_STATE_DIR") or (Path(tempfile.gettempdir()) / "sagi_cloud_state"))
RENDER_STATE_FILE = STATE_DIR / "render_jobs.json"
voice_cache = {"at": 0.0, "voices": []}

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

def caption_rate_allowed():
    key = request.headers.get("X-Forwarded-For", request.remote_addr or "unknown").split(",")[0].strip()
    cutoff = time.time() - 3600
    with caption_rate_lock:
        arr = [t for t in caption_rate_hits.get(key, []) if t >= cutoff]
        if len(arr) >= CAPTION_RATE_LIMIT_PER_HOUR:
            caption_rate_hits[key] = arr
            return False
        arr.append(time.time())
        caption_rate_hits[key] = arr
    return True

SOCIAL_DOWNLOAD_HOSTS = (
    "instagram.com", "youtube.com", "youtu.be",
    "tiktok.com", "x.com", "twitter.com",
)

def _url_host(url):
    try:
        u = urlparse(url)
        if u.scheme not in ("http", "https"):
            return ""
        return (u.hostname or "").lower().strip(".")
    except Exception:
        return ""

def allowed_social_url(url):
    host = _url_host(url)
    if not host:
        return False
    return any(host == root or host.endswith("." + root) for root in SOCIAL_DOWNLOAD_HOSTS)

def is_instagram_url(url):
    host = _url_host(url)
    return host == "instagram.com" or host.endswith(".instagram.com")

def safe_name(name):
    raw = (name or "SAGI_INS_VIDEO").strip()
    clean = "".join(c for c in raw if c not in '\\/:*?"<>|').strip()
    return (clean or "SAGI_INS_VIDEO")[:100]


def _persist_render_jobs_locked():
    """Persist render metadata so a gunicorn/process restart does not become a blind 404."""
    try:
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        payload = {jid: dict(job) for jid, job in render_jobs.items()}
        tmp = RENDER_STATE_FILE.with_suffix(".tmp")
        tmp.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")
        tmp.replace(RENDER_STATE_FILE)
    except Exception as e:
        print("render state persist failed:", str(e)[:300], flush=True)


def _restore_render_jobs():
    if not RENDER_STATE_FILE.exists():
        return
    try:
        payload = json.loads(RENDER_STATE_FILE.read_text(encoding="utf-8") or "{}")
    except Exception as e:
        print("render state restore failed:", str(e)[:300], flush=True)
        return
    if not isinstance(payload, dict):
        return

    resume = []
    with render_jobs_lock:
        for jid, raw in payload.items():
            if not isinstance(raw, dict):
                continue
            job = dict(raw)
            job["id"] = str(job.get("id") or jid)
            status = str(job.get("status") or "failed")
            source = Path(str(job.get("source") or ""))
            if status in ("queued", "processing"):
                if source.exists():
                    job.update({
                        "status": "queued",
                        "stage": "服务重启 · 自动恢复任务",
                        "progress": max(5, min(15, int(job.get("progress") or 8))),
                        "updated_at": iso(),
                        "error": "",
                    })
                    resume.append((job["id"], job.get("options") or {}))
                else:
                    # Keep the record so the phone receives a recoverable failure instead of 404.
                    job.update({
                        "status": "failed",
                        "stage": "服务已重启",
                        "progress": 0,
                        "updated_at": iso(),
                        "error": "云端实例已重启，源视频临时文件不可恢复，请自动重新提交。",
                    })
            render_jobs[job["id"]] = job
        _persist_render_jobs_locked()

    for jid, options in resume:
        Thread(target=run_cloud_render, args=(jid, options), daemon=True).start()


def release_caption_model():
    global caption_model
    if caption_model is not None:
        try:
            del caption_model
        except Exception:
            pass
        caption_model = None
    gc.collect()


def public_render_job(job):
    data = {
        "id": job["id"],
        "status": job.get("status", "queued"),
        "stage": job.get("stage", ""),
        "progress": int(job.get("progress", 0) or 0),
        "createdAt": job.get("created_at", ""),
        "updatedAt": job.get("updated_at", ""),
        "error": job.get("error", ""),
        "size": int(job.get("size", 0) or 0),
    }
    if job.get("status") == "ready":
        base = request.host_url.rstrip("/") + f"/api/render-jobs/{job['id']}/file?key={job['download_key']}"
        data["previewUrl"] = base
        data["downloadUrl"] = base + "&download=1"
    return data

def ensure_cjk_font():
    FONT_DIR.mkdir(parents=True, exist_ok=True)
    if FONT_PATH.exists() and FONT_PATH.stat().st_size > 1_000_000:
        return str(FONT_PATH)
    tmp = FONT_PATH.with_suffix(".part")
    r = requests.get(FONT_URL, stream=True, timeout=90)
    r.raise_for_status()
    with tmp.open("wb") as f:
        for chunk in r.iter_content(1024 * 256):
            if chunk:
                f.write(chunk)
    if tmp.stat().st_size < 1_000_000:
        tmp.unlink(missing_ok=True)
        raise RuntimeError("CJK font download incomplete")
    tmp.replace(FONT_PATH)
    return str(FONT_PATH)

def _eleven_headers():
    if not ELEVENLABS_API_KEY:
        raise RuntimeError("ELEVENLABS_NOT_CONFIGURED")
    return {"xi-api-key": ELEVENLABS_API_KEY}

def list_eleven_voices(force=False):
    if not ELEVENLABS_API_KEY:
        return []
    if not force and voice_cache["voices"] and time.time() - voice_cache["at"] < 600:
        return voice_cache["voices"]
    r = requests.get(
        ELEVENLABS_BASE + "/v2/voices",
        headers=_eleven_headers(),
        params={"page_size": 100, "include_total_count": "false"},
        timeout=30,
    )
    r.raise_for_status()
    raw = (r.json() or {}).get("voices") or []
    voices = []
    for v in raw:
        labels = v.get("labels") or {}
        voices.append({
            "voice_id": str(v.get("voice_id") or ""),
            "name": str(v.get("name") or "Voice"),
            "category": str(v.get("category") or ""),
            "gender": str(labels.get("gender") or "").lower(),
            "accent": str(labels.get("accent") or ""),
            "language": str(labels.get("language") or ""),
            "preview_url": v.get("preview_url") or "",
        })
    voice_cache["voices"] = [x for x in voices if x["voice_id"]]
    voice_cache["at"] = time.time()
    return voice_cache["voices"]

def resolve_voice_id(mode, explicit=""):
    if explicit:
        return explicit
    configured_default = ELEVENLABS_MALE_VOICE_ID if mode == "ai_male" else ELEVENLABS_FEMALE_VOICE_ID
    if configured_default:
        return configured_default
    voices = list_eleven_voices()
    wanted = "male" if mode == "ai_male" else "female"
    for v in voices:
        if v.get("gender") == wanted and v.get("category") in ("premade", "generated", "cloned", ""):
            return v["voice_id"]
    for v in voices:
        if v.get("gender") == wanted:
            return v["voice_id"]
    if voices:
        return voices[0]["voice_id"]
    raise RuntimeError("NO_ELEVENLABS_VOICE_AVAILABLE")

def synthesize_eleven(text, voice_id, output_path, speed=1.0):
    if not text.strip():
        raise RuntimeError("EMPTY_NARRATION")
    voice_id = voice_id.strip()
    if not voice_id:
        raise RuntimeError("VOICE_ID_REQUIRED")
    payload = {
        "text": text[:10000],
        "model_id": "eleven_flash_v2_5",
        "voice_settings": {
            "stability": 0.46,
            "similarity_boost": 0.78,
            "style": 0.12,
            "use_speaker_boost": True,
            "speed": max(0.75, min(1.25, float(speed or 1.0))),
        },
    }
    r = requests.post(
        ELEVENLABS_BASE + f"/v1/text-to-speech/{voice_id}",
        headers={**_eleven_headers(), "Content-Type": "application/json", "Accept": "audio/mpeg"},
        params={"output_format": "mp3_44100_128"},
        json=payload,
        timeout=120,
        stream=True,
    )
    if r.status_code >= 400:
        raise RuntimeError("ELEVENLABS_TTS: " + r.text[:400])
    with Path(output_path).open("wb") as out:
        for chunk in r.iter_content(chunk_size=64 * 1024):
            if chunk:
                out.write(chunk)
    if Path(output_path).stat().st_size < 1000:
        raise RuntimeError("ELEVENLABS_EMPTY_AUDIO")
    return str(output_path)


def synthesize_edge_tts(text, mode, output_path, speed=1.0):
    if not str(text or "").strip():
        raise RuntimeError("EMPTY_NARRATION")
    try:
        import asyncio
        import edge_tts
        voice = "zh-CN-YunjianNeural" if mode == "ai_male" else "zh-CN-XiaoxiaoNeural"
        rate = int(round((max(0.75, min(1.25, float(speed or 1.0))) - 1.0) * 100))
        async def _save():
            communicate = edge_tts.Communicate(str(text)[:10000], voice=voice, rate=f"{rate:+d}%")
            await communicate.save(str(output_path))
        asyncio.run(_save())
        if not Path(output_path).exists() or Path(output_path).stat().st_size < 1000:
            raise RuntimeError("EDGE_TTS_EMPTY_AUDIO")
        return str(output_path)
    except Exception as e:
        raise RuntimeError("EDGE_TTS: " + str(e)[:500])

def synthesize_voice(text, mode, voice_id, output_path, speed=1.0):
    mode = str(mode or "ai_male")
    voice_id = str(voice_id or "").strip()
    if mode == "clone":
        if not ELEVENLABS_API_KEY:
            raise RuntimeError("VOICE_CLONE_REQUIRES_ELEVENLABS")
        selected = resolve_voice_id(mode, voice_id)
        return synthesize_eleven(text, selected, output_path, speed)

    # Premium path first; generic AI voices fall back automatically to keyless Edge Neural.
    if ELEVENLABS_API_KEY:
        try:
            selected = resolve_voice_id(mode, voice_id)
            return synthesize_eleven(text, selected, output_path, speed)
        except Exception as e:
            print("ElevenLabs generic TTS fallback:", str(e)[:300], flush=True)

    return synthesize_edge_tts(text, mode, output_path, speed)

def media_has_audio(path):
    try:
        import av
        with av.open(str(path), metadata_errors="ignore") as container:
            return any(getattr(s, "type", "") == "audio" for s in container.streams)
    except TypeError:
        import av
        with av.open(str(path)) as container:
            return any(getattr(s, "type", "") == "audio" for s in container.streams)
    except Exception:
        return True

def ass_time(sec):
    n = max(0.0, float(sec or 0))
    h = int(n // 3600)
    m = int((n % 3600) // 60)
    s = n % 60
    return f"{h}:{m:02d}:{s:05.2f}"

def ass_escape(text):
    return str(text or "").replace("\\", r"\\").replace("{", r"\{").replace("}", r"\}").replace("\n", r"\N")

def write_ass(captions, path, width, height):
    font_size = 46 if width <= 720 else 64
    margin_v = 105 if height <= 1280 else 155
    header = f"""[Script Info]
ScriptType: v4.00+
PlayResX: {width}
PlayResY: {height}
ScaledBorderAndShadow: yes
WrapStyle: 2

[V4+ Styles]
Format: Name,Fontname,Fontsize,PrimaryColour,SecondaryColour,OutlineColour,BackColour,Bold,Italic,Underline,StrikeOut,ScaleX,ScaleY,Spacing,Angle,BorderStyle,Outline,Shadow,Alignment,MarginL,MarginR,MarginV,Encoding
Style: Default,Noto Sans CJK SC,{font_size},&H00FFFFFF,&H000000FF,&HCC000000,&H66000000,-1,0,0,0,100,100,0,0,1,4,0,2,60,60,{margin_v},1

[Events]
Format: Layer,Start,End,Style,Name,MarginL,MarginR,MarginV,Effect,Text
"""
    lines = [header]
    for c in captions or []:
        start = max(0.0, float(c.get("start") or 0))
        end = max(start + 0.05, float(c.get("end") or start + 1))
        text = ass_escape(c.get("text") or "")
        if text:
            lines.append(f"Dialogue: 0,{ass_time(start)},{ass_time(end)},Default,,0,0,0,,{text}\n")
    Path(path).write_text("".join(lines), encoding="utf-8")
    return str(path)

def render_dimensions(aspect, quality):
    if quality == "high":
        if aspect == "16:9":
            return 1920, 1080
        if aspect == "1:1":
            return 1080, 1080
        return 1080, 1920
    if aspect == "16:9":
        return 1280, 720
    if aspect == "1:1":
        return 720, 720
    return 720, 1280

def run_cloud_render(job_id, options):
    # Cloud render is intentionally serialized with caption transcription.
    with heavy_slot:
        with render_jobs_lock:
            job = render_jobs.get(job_id)
            if not job:
                return
            job.update({"status": "processing", "stage": "准备云端渲染", "progress": 12, "updated_at": iso()})
            _persist_render_jobs_locked()
            work = Path(job["workdir"])
            source = Path(job["source"])
        try:
            duration = max(0.2, min(180.0, float(options.get("duration") or 15)))
            start = max(0.0, float(options.get("start") or 0))
            aspect = str(options.get("aspect") or "9:16")
            quality = str(options.get("quality") or "fast")
            captions = options.get("captions") or []
            narration = str(options.get("narration") or "").strip()
            voice_mode = str(options.get("voice_mode") or "none")
            voice_id = str(options.get("voice_id") or "").strip()
            voice_speed = float(options.get("voice_speed") or 1.0)
            original_volume = max(0.0, min(1.0, float(options.get("original_volume") or 0.25)))
            burn_subtitles = bool(options.get("burn_subtitles", True))

            narration_path = None
            uploaded_voice = options.get("uploaded_voice")
            if uploaded_voice and Path(uploaded_voice).exists():
                narration_path = Path(uploaded_voice)
            elif voice_mode in ("ai_male", "ai_female", "clone") and narration:
                with render_jobs_lock:
                    render_jobs[job_id].update({"stage": "生成 AI 配音", "progress": 20, "updated_at": iso()})
                    _persist_render_jobs_locked()
                narration_path = work / "narration.mp3"
                synthesize_voice(narration, voice_mode, voice_id, narration_path, voice_speed)

            width, height = render_dimensions(aspect, quality)
            vf = f"scale={width}:{height}:force_original_aspect_ratio=increase,crop={width}:{height},setsar=1"
            ass_path = None
            if burn_subtitles and captions:
                ensure_cjk_font()
                ass_path = work / "captions.ass"
                write_ass(captions, ass_path, width, height)
                ass_escaped = str(ass_path).replace("\\", "/").replace(":", r"\:").replace("'", r"\'")
                font_escaped = str(FONT_DIR).replace("\\", "/").replace(":", r"\:").replace("'", r"\'")
                vf += f",subtitles='{ass_escaped}':fontsdir='{font_escaped}'"

            exe = imageio_ffmpeg.get_ffmpeg_exe()
            out = work / "SAGI_CLOUD_RENDER.mp4"
            cmd = [exe, "-hide_banner", "-y", "-ss", str(start), "-t", str(duration), "-i", str(source)]
            if narration_path:
                cmd += ["-i", str(narration_path)]

            filters = [f"[0:v]{vf}[vout]"]
            has_audio = media_has_audio(source)
            audio_map = None
            if narration_path and has_audio and original_volume > 0:
                filters += [
                    f"[0:a]volume={original_volume}[a0]",
                    "[1:a]volume=1[a1]",
                    "[a0][a1]amix=inputs=2:duration=first:dropout_transition=1[aout]",
                ]
                audio_map = "[aout]"
            elif narration_path:
                filters += ["[1:a]volume=1[aout]"]
                audio_map = "[aout]"
            elif has_audio and original_volume > 0:
                if original_volume != 1:
                    filters += [f"[0:a]volume={original_volume}[aout]"]
                    audio_map = "[aout]"
                else:
                    audio_map = "0:a?"
            cmd += ["-filter_complex", ";".join(filters), "-map", "[vout]"]
            if audio_map:
                cmd += ["-map", audio_map]
            else:
                cmd += ["-an"]

            if quality == "high":
                preset, crf = "veryfast", "21"
            elif quality == "balanced":
                preset, crf = "veryfast", "23"
            else:
                preset, crf = "ultrafast", "26"
            cmd += [
                "-c:v", "libx264", "-preset", preset, "-tune", "zerolatency", "-crf", crf,
                "-threads", str(FFMPEG_THREADS),
                "-filter_threads", "1", "-filter_complex_threads", "1",
                "-pix_fmt", "yuv420p", "-r", "30",
            ]
            if audio_map:
                cmd += ["-c:a", "aac", "-b:a", "128k"]
            cmd += ["-movflags", "+faststart", "-t", str(duration), "-progress", "pipe:1", "-nostats", str(out)]

            with render_jobs_lock:
                render_jobs[job_id].update({"stage": "云端编码成片", "progress": 34, "updated_at": iso()})
                _persist_render_jobs_locked()
            proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
            logs = []
            for line in proc.stdout or []:
                line = line.strip()
                if line:
                    logs.append(line)
                    if len(logs) > 80:
                        logs = logs[-80:]
                if line.startswith("out_time_ms="):
                    try:
                        sec = float(line.split("=", 1)[1]) / 1_000_000.0
                        pct = 34 + int(min(60, max(0, sec / duration * 60)))
                        with render_jobs_lock:
                            if job_id in render_jobs:
                                render_jobs[job_id].update({"progress": pct, "updated_at": iso()})
                    except Exception:
                        pass
            code = proc.wait()
            if code != 0 or not out.exists() or out.stat().st_size < 5000:
                raise RuntimeError("FFMPEG_RENDER_FAILED: " + " | ".join(logs[-12:]))

            with render_jobs_lock:
                render_jobs[job_id].update({
                    "status": "ready", "stage": "成片完成", "progress": 100,
                    "updated_at": iso(), "path": str(out), "size": out.stat().st_size,
                    "filename": "SAGI_CLOUD_RENDER.mp4", "error": "",
                })
                _persist_render_jobs_locked()
        except Exception as e:
            with render_jobs_lock:
                if job_id in render_jobs:
                    render_jobs[job_id].update({
                        "status": "failed", "stage": "失败", "progress": 0,
                        "updated_at": iso(), "error": str(e)[:1200],
                    })
                    _persist_render_jobs_locked()
        finally:
            gc.collect()

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
        # Prefer one-file MP4 to avoid memory/CPU-heavy FFmpeg merges on Render.
        "format": "best[ext=mp4]/best",
        "outtmpl": outtmpl,
        "noplaylist": True,
        "quiet": True,
        "no_warnings": True,
        "restrictfilenames": True,
        "retries": 2,
        "fragment_retries": 2,
        "socket_timeout": 25,
        "sleep_interval_requests": 1,
        "max_sleep_interval": 3,
        "max_filesize": MAX_FILE_MB * 1024 * 1024,
        "http_headers": {
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 Version/18.5 Mobile/15E148 Safari/604.1",
            "Accept-Language": "en-US,en;q=0.9",
        },
    }
    if INSTAGRAM_PROXY:
        common["proxy"] = INSTAGRAM_PROXY

    if is_instagram_url(url):
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
        elif strategy == "web":
            common["extractor_args"] = {"instagram": {"app_id": ["web"]}}

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
    strategies = ["web", "ios", "android"] if is_instagram_url(url) else ["direct"]
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
            # Optional self-hosted Cobalt remains a fallback, never the primary path.
            if cobalt_base():
                shutil.rmtree(work, ignore_errors=True)
                run_cobalt_download(job_id, url, wanted_name)
                return
            if saw_429:
                raise RuntimeError(
                    "SAGI_DOWNLOAD_RATE_LIMIT: source platform temporarily rejected the cloud IP."
                )
            raise RuntimeError("SAGI cloud extraction failed: " + " | ".join(errors[-2:]))

        files = [
            p for p in Path(work).iterdir()
            if p.is_file() and not p.name.endswith((".part", ".ytdl", ".json"))
        ]
        if not files:
            raise RuntimeError("源平台未返回可下载的视频文件")

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
        code = "cloud_download_rate_limit" if "SAGI_DOWNLOAD_RATE_LIMIT" in msg else "cloud_download_failed"
        with jobs_lock:
            job = jobs.get(job_id)
            if job:
                job.update({
                    "status": "failed",
                    "updated_at": iso(),
                    "error": msg[:700],
                    "errorCode": code,
                })

def get_caption_model():
    global caption_model, caption_model_error, caption_ready_at
    if caption_model is not None:
        return caption_model
    with caption_model_lock:
        if caption_model is not None:
            return caption_model
        try:
            source = CAPTION_MODEL_DIR if Path(CAPTION_MODEL_DIR).exists() else "Systran/faster-whisper-tiny"
            caption_model = WhisperModel(
                source,
                device="cpu",
                compute_type="int8",
                cpu_threads=max(1, min(4, os.cpu_count() or 2)),
                num_workers=1,
            )
            caption_model_error = ""
            caption_ready_at = time.time()
            return caption_model
        except Exception as e:
            caption_model_error = str(e)[:500]
            raise

def warm_caption_model():
    try:
        get_caption_model()
    except Exception:
        pass

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
        render_remove = []
        with render_jobs_lock:
            for job_id, job in render_jobs.items():
                try:
                    created = datetime.fromisoformat(job["created_at"])
                except Exception:
                    created = now()
                if created < cutoff:
                    render_remove.append(job_id)
            for job_id in render_remove:
                job = render_jobs.pop(job_id, None)
                if job and job.get("workdir"):
                    shutil.rmtree(job["workdir"], ignore_errors=True)
        time.sleep(60)

Thread(target=cleanup_loop, daemon=True).start()
_restore_render_jobs()
# Caption model is loaded lazily on first caption request to keep health checks responsive.

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
        "deployRevision": DEPLOY_REVISION,
        "version": APP_VERSION,
        "instagram": True,
        "cloudDownload": True,
        "cloudDownloadVersion": "1.0",
        "downloadPlatforms": ["Instagram", "YouTube", "TikTok", "X"],
        "hybridWorker": True,
        "workerOnline": worker_online(),
        "activation": True,
        "captionFast": True,
        "captionMedia": True,
        "contextTranslate": True,
        "smartTranslate": True,
        "aiVoice": True,
        "aiVoiceFallback": True,
        "voiceClone": bool(ELEVENLABS_API_KEY),
        "cloudRender": True,
        "cloudRenderStable": True,
        "heavyTaskConcurrency": 1,
        "ffmpegThreads": FFMPEG_THREADS,
        "renderStateRecovery": True,
        "elevenLabsConfigured": bool(ELEVENLABS_API_KEY),
        "captionModel": "faster-whisper-tiny-int8",
        "captionMaxSeconds": 180,
        "captionRateLimitPerHour": CAPTION_RATE_LIMIT_PER_HOUR,
        "captionReady": caption_model is not None,
        "captionModelCached": Path(CAPTION_MODEL_DIR).exists(),
        "captionMediaMaxMB": CAPTION_MEDIA_MAX_MB,
        "captionError": caption_model_error,
        "maxFileMB": MAX_FILE_MB,
        "jobTTLMinutes": JOB_TTL_MIN,
        "configured": bool(SERVER_SECRET),
    })

@app.post("/api/caption-media")
def caption_media_fast():
    if not authorized():
        return jsonify({"ok": False, "error": "Unauthorized"}), 401
    if not caption_rate_allowed():
        return jsonify({"ok": False, "error": "Caption hourly limit reached", "errorCode": "caption_rate_limit"}), 429

    upload = request.files.get("media")
    if not upload:
        return jsonify({"ok": False, "error": "Media file required"}), 400

    raw_lang = (request.form.get("language") or "").strip().lower()
    language = None if raw_lang in ("", "auto") else raw_lang
    if language == "zh-cn":
        language = "zh"

    try:
        start = max(0.0, float(request.form.get("start") or 0))
        duration = max(0.1, min(180.0, float(request.form.get("duration") or 180)))
    except Exception:
        start, duration = 0.0, 180.0
    end = start + duration

    work = tempfile.mkdtemp(prefix="sagi_caption_media_")
    suffix = Path(upload.filename or "media.mp4").suffix or ".mp4"
    path = Path(work) / ("source" + suffix)
    started = time.time()

    try:
        upload.save(path)
        size = path.stat().st_size if path.exists() else 0
        if size <= 0:
            return jsonify({"ok": False, "error": "Empty media"}), 400
        if size > CAPTION_MEDIA_MAX_MB * 1024 * 1024:
            return jsonify({"ok": False, "error": f"Media exceeds {CAPTION_MEDIA_MAX_MB}MB"}), 413

        with heavy_slot:
            model = get_caption_model()
            try:
                segments, info = model.transcribe(
                    str(path),
                    language=language,
                    task="transcribe",
                    beam_size=1,
                    best_of=1,
                    temperature=0.0,
                    vad_filter=False,
                    clip_timestamps=f"{start},{end}",
                    word_timestamps=False,
                    condition_on_previous_text=False,
                )

                items = []
                for seg in segments:
                    text = (seg.text or "").strip()
                    if not text:
                        continue
                    items.append({
                        "start": round(max(0.0, float(seg.start) - start), 3),
                        "end": round(max(0.0, float(seg.end) - start), 3),
                        "text": text,
                    })
            finally:
                release_caption_model()

        return jsonify({
            "ok": True,
            "engine": "faster-whisper-tiny-int8-media",
            "language": getattr(info, "language", language or ""),
            "languageProbability": round(float(getattr(info, "language_probability", 0.0) or 0.0), 4),
            "segments": items,
            "elapsedMs": int((time.time() - started) * 1000),
            "processedSeconds": round(duration, 2),
        })
    except Exception as e:
        return jsonify({
            "ok": False,
            "error": str(e)[:700],
            "errorCode": "caption_media_failed",
        }), 500
    finally:
        shutil.rmtree(work, ignore_errors=True)


@app.post("/api/caption")
def caption_fast():
    if not authorized():
        return jsonify({"ok": False, "error": "Unauthorized"}), 401
    if not caption_rate_allowed():
        return jsonify({"ok": False, "error": "Caption hourly limit reached", "errorCode": "caption_rate_limit"}), 429

    upload = request.files.get("audio")
    if not upload:
        return jsonify({"ok": False, "error": "Audio file required"}), 400

    raw_lang = (request.form.get("language") or "").strip().lower()
    language = None if raw_lang in ("", "auto") else raw_lang
    if language == "zh-cn":
        language = "zh"

    work = tempfile.mkdtemp(prefix="sagi_caption_")
    path = Path(work) / "caption.wav"
    started = time.time()
    try:
        upload.save(path)
        size = path.stat().st_size if path.exists() else 0
        if size <= 0:
            return jsonify({"ok": False, "error": "Empty audio"}), 400
        if size > CAPTION_MAX_MB * 1024 * 1024:
            return jsonify({"ok": False, "error": f"Audio exceeds {CAPTION_MAX_MB}MB"}), 413

        with heavy_slot:
            model = get_caption_model()
            try:
                segments, info = model.transcribe(
                    str(path),
                    language=language,
                    task="transcribe",
                    beam_size=1,
                    best_of=1,
                    temperature=0.0,
                    vad_filter=True,
                    vad_parameters={"min_silence_duration_ms": 350},
                    word_timestamps=False,
                    condition_on_previous_text=False,
                )
                items = []
                for seg in segments:
                    text = (seg.text or "").strip()
                    if not text:
                        continue
                    items.append({
                        "start": round(float(seg.start), 3),
                        "end": round(float(seg.end), 3),
                        "text": text,
                    })
            finally:
                release_caption_model()

        return jsonify({
            "ok": True,
            "engine": "faster-whisper-tiny-int8",
            "language": getattr(info, "language", language or ""),
            "languageProbability": round(float(getattr(info, "language_probability", 0.0) or 0.0), 4),
            "segments": items,
            "elapsedMs": int((time.time() - started) * 1000),
        })
    except Exception as e:
        return jsonify({
            "ok": False,
            "error": str(e)[:700],
            "errorCode": "caption_failed",
        }), 500
    finally:
        shutil.rmtree(work, ignore_errors=True)


def _google_translate_text(text, source, target):
    params = {
        "client": "gtx",
        "sl": source or "auto",
        "tl": target or "zh-CN",
        "dt": "t",
        "q": text,
    }
    r = requests.get(
        "https://translate.googleapis.com/translate_a/single",
        params=params,
        headers={"User-Agent": "Mozilla/5.0"},
        timeout=30,
    )
    r.raise_for_status()
    data = r.json()
    chunks = data[0] if isinstance(data, list) and data else []
    return "".join((x[0] or "") for x in chunks if isinstance(x, list) and x)

def _football_zh_polish(text):
    # Longest/specific phrases first; generic “转换” is handled with a guarded regex
    # so already-correct “攻防转换” never becomes “攻防攻防转换”.
    replacements = [
        ("低位封锁", "低位防守"),
        ("低位块", "低位防守阵型"),
        ("转换阶段", "攻防转换阶段"),
        ("双支点", "双后腰"),
        ("后四人", "四后卫防线"),
        ("半空间", "肋部"),
        ("反压迫", "丢球后反抢"),
        ("过载", "局部人数优势"),
        ("高压", "高位逼抢"),
        ("双轴", "双后腰"),
        ("后四", "四后卫防线"),
    ]
    out = text or ""
    for a, b in replacements:
        out = out.replace(a, b)
    out = re.sub(r"(?<!攻防)转换", "攻防转换", out)
    return out

FOOTBALL_GLOSSARY_EN_ZH = {
    "back four": "四后卫防线",
    "double pivot": "双后腰",
    "half-space": "肋部",
    "half space": "肋部",
    "high press": "高位逼抢",
    "high pressing": "高位逼抢",
    "counter-press": "丢球后反抢",
    "counterpress": "丢球后反抢",
    "low block": "低位防守",
    "mid block": "中位防守",
    "build-up": "后场组织",
    "build up": "后场组织",
    "transition": "攻防转换",
    "overload": "局部人数优势",
    "third-man run": "第三人跑动",
    "third man run": "第三人跑动",
    "rest defence": "进攻保障防守",
    "rest defense": "进攻保障防守",
    "inverted full-back": "内收边后卫",
    "inverted fullback": "内收边后卫",
}

def _normalize_words(text):
    return [x for x in re.findall(r"[a-z0-9']+", (text or "").lower()) if len(x) > 1]

def _back_translation_score(source, back, translated, target):
    src = _normalize_words(source)
    rev = _normalize_words(back)
    if src:
        a, b = set(src), set(rev)
        overlap = len(a & b) / max(1, len(a))
    else:
        overlap = 0.72
    src_len = max(1, len(source or ""))
    back_len = max(1, len(back or ""))
    length_ratio = min(src_len, back_len) / max(src_len, back_len)
    zh_ratio = 1.0
    if str(target).lower().startswith("zh"):
        compact = re.sub(r"\s+", "", translated or "")
        zh_ratio = len(re.findall(r"[\u3400-\u9fff]", compact)) / max(1, len(compact))
        zh_ratio = min(1.0, zh_ratio / 0.25)
    return round(max(0.0, min(1.0, overlap * 0.58 + length_ratio * 0.22 + zh_ratio * 0.20)) * 100, 1)

def _protect_football_terms(text, source, target):
    if not str(target).lower().startswith("zh"):
        return text, {}
    if not str(source).lower().startswith("en"):
        return text, {}
    protected = text or ""
    restore = {}
    items = sorted(FOOTBALL_GLOSSARY_EN_ZH.items(), key=lambda x: len(x[0]), reverse=True)
    idx = 0
    for term, zh in items:
        pattern = re.compile(r"\b" + re.escape(term) + r"\b", re.I)
        if pattern.search(protected):
            token = f"SAGITERM{idx:02d}X"
            protected = pattern.sub(token, protected)
            restore[token] = zh
            idx += 1
    return protected, restore

def _restore_football_terms(text, restore):
    out = text or ""
    for token, value in restore.items():
        out = out.replace(token, value).replace(token.lower(), value)
    return out

def _mymemory_translate_text(text, source, target):
    src = "en" if source in ("", "auto") else source
    if src == "zh-CN":
        src = "zh"
    params = {"q": text, "langpair": f"{src}|{target}"}
    r = requests.get("https://api.mymemory.translated.net/get", params=params, timeout=30)
    r.raise_for_status()
    data = r.json()
    out = str(((data.get("responseData") or {}).get("translatedText") or "")).strip()
    if not out:
        raise RuntimeError("MyMemory empty result")
    return out

def _smart_translate_paragraph(text, source, target, mode):
    protected, restore = _protect_football_terms(text, source, target)
    primary = _google_translate_text(protected, source, target).strip()
    primary = _restore_football_terms(primary, restore)
    if mode == "football" and str(target).lower().startswith("zh"):
        primary = _football_zh_polish(primary)

    back_source = "en" if source in ("", "auto") else source
    try:
        back = _google_translate_text(primary, target, back_source).strip()
        score = _back_translation_score(text, back, primary, target)
    except Exception:
        back, score = "", 72.0

    engine = "google-smart"
    issues = []
    if score < 68:
        issues.append("low_back_translation_score")
        try:
            alt = _mymemory_translate_text(protected, source, target).strip()
            alt = _restore_football_terms(alt, restore)
            if mode == "football" and str(target).lower().startswith("zh"):
                alt = _football_zh_polish(alt)
            alt_back = _google_translate_text(alt, target, back_source).strip()
            alt_score = _back_translation_score(text, alt_back, alt, target)
            if alt_score > score:
                primary, back, score, engine = alt, alt_back, alt_score, "mymemory-smart"
        except Exception:
            pass

    return {"text": primary, "back": back, "score": score, "engine": engine, "issues": issues}

@app.post("/api/translate-smart")
def translate_smart():
    if not authorized():
        return jsonify({"ok": False, "error": "Unauthorized"}), 401
    if not caption_rate_allowed():
        return jsonify({"ok": False, "error": "Translation hourly limit reached", "errorCode": "caption_rate_limit"}), 429
    data = request.get_json(silent=True) or {}
    source = str(data.get("source") or "auto").strip()
    target = str(data.get("target") or "zh-CN").strip()
    mode = str(data.get("mode") or "faithful").strip()
    paragraphs = data.get("paragraphs") or []
    if not isinstance(paragraphs, list) or not paragraphs:
        return jsonify({"ok": False, "error": "paragraphs required"}), 400
    paragraphs = [str(x or "").strip() for x in paragraphs[:80]]
    started = time.time()
    try:
        results = [_smart_translate_paragraph(x, source, target, mode) for x in paragraphs]
        scores = [float(x.get("score") or 0) for x in results]
        return jsonify({
            "ok": True,
            "engine": "sagi-smart-translate-v1",
            "source": source,
            "target": target,
            "mode": mode,
            "results": results,
            "averageScore": round(sum(scores) / max(1, len(scores)), 1),
            "elapsedMs": int((time.time() - started) * 1000),
        })
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)[:700], "errorCode": "smart_translate_failed"}), 500


@app.post("/api/translate-context")
def translate_context():
    if not authorized():
        return jsonify({"ok": False, "error": "Unauthorized"}), 401
    if not caption_rate_allowed():
        return jsonify({"ok": False, "error": "Translation hourly limit reached", "errorCode": "caption_rate_limit"}), 429

    data = request.get_json(silent=True) or {}
    source = str(data.get("source") or "auto").strip()
    target = str(data.get("target") or "zh-CN").strip()
    mode = str(data.get("mode") or "faithful").strip()
    segments = data.get("segments") or []
    if not isinstance(segments, list) or not segments:
        return jsonify({"ok": False, "error": "segments required"}), 400
    segments = [str(x or "").strip() for x in segments[:240]]
    if not any(segments):
        return jsonify({"ok": False, "error": "empty segments"}), 400

    started = time.time()
    translated = [""] * len(segments)
    block_size = 6

    try:
        for block_start in range(0, len(segments), block_size):
            block = segments[block_start:block_start + block_size]
            marked = "\n".join(
                f"[[SAGI_{block_start + i:03d}]] {line}"
                for i, line in enumerate(block)
            )
            out = _google_translate_text(marked, source, target)

            import re
            pattern = re.compile(r"\[\[SAGI_(\d{3})\]\]\s*")
            matches = list(pattern.finditer(out))
            if matches:
                for j, m in enumerate(matches):
                    idx = int(m.group(1))
                    end = matches[j + 1].start() if j + 1 < len(matches) else len(out)
                    text = out[m.end():end].strip()
                    if 0 <= idx < len(translated):
                        translated[idx] = text
            else:
                # Marker preservation failed: translate each line separately for this small block.
                for i, line in enumerate(block):
                    translated[block_start + i] = _google_translate_text(line, source, target).strip()

        for i, original in enumerate(segments):
            if not translated[i]:
                translated[i] = _google_translate_text(original, source, target).strip()

        if mode == "football" and target.lower().startswith("zh"):
            translated = [_football_zh_polish(x) for x in translated]

        return jsonify({
            "ok": True,
            "engine": "google-context",
            "mode": mode,
            "source": source,
            "target": target,
            "segments": translated,
            "elapsedMs": int((time.time() - started) * 1000),
        })
    except Exception as e:
        return jsonify({
            "ok": False,
            "error": str(e)[:700],
            "errorCode": "context_translate_failed",
        }), 500


@app.get("/api/voice/status")
def voice_status():
    if not authorized():
        return jsonify({"ok": False, "error": "Unauthorized"}), 401
    voices = []
    error = ""
    if ELEVENLABS_API_KEY:
        try:
            voices = list_eleven_voices()
        except Exception as e:
            error = str(e)[:400]
    fallback_voices = [
        {"voice_id": "edge-zh-male", "name": "Microsoft 云健", "category": "fallback", "gender": "male", "accent": "zh-CN", "language": "zh-CN", "preview_url": ""},
        {"voice_id": "edge-zh-female", "name": "Microsoft 晓晓", "category": "fallback", "gender": "female", "accent": "zh-CN", "language": "zh-CN", "preview_url": ""},
    ]
    return jsonify({
        "ok": True,
        "configured": True,
        "premiumConfigured": bool(ELEVENLABS_API_KEY),
        "cloneConfigured": bool(ELEVENLABS_API_KEY),
        "provider": "ElevenLabs + Microsoft Edge" if ELEVENLABS_API_KEY else "Microsoft Edge Neural",
        "model": "eleven_flash_v2_5" if ELEVENLABS_API_KEY else "edge-neural",
        "voiceCount": len(voices) + len(fallback_voices),
        "voices": (voices[:28] + fallback_voices) if ELEVENLABS_API_KEY else fallback_voices,
        "error": error,
    })

@app.post("/api/voice/clone")
def voice_clone():
    if not authorized():
        return jsonify({"ok": False, "error": "Unauthorized"}), 401
    if not ELEVENLABS_API_KEY:
        return jsonify({"ok": False, "error": "ELEVENLABS_NOT_CONFIGURED"}), 503
    if str(request.form.get("consent") or "").lower() not in ("1", "true", "yes"):
        return jsonify({"ok": False, "error": "Voice owner consent required"}), 400
    sample = request.files.get("sample")
    if not sample:
        return jsonify({"ok": False, "error": "Voice sample required"}), 400
    work = tempfile.mkdtemp(prefix="sagi_voice_clone_")
    suffix = Path(sample.filename or "voice.m4a").suffix or ".m4a"
    sample_path = Path(work) / ("sample" + suffix)
    sample.save(sample_path)
    if not sample_path.exists() or sample_path.stat().st_size <= 0:
        shutil.rmtree(work, ignore_errors=True)
        return jsonify({"ok": False, "error": "Empty voice sample"}), 400
    if sample_path.stat().st_size > VOICE_SAMPLE_MAX_MB * 1024 * 1024:
        shutil.rmtree(work, ignore_errors=True)
        return jsonify({"ok": False, "error": f"Voice sample exceeds {VOICE_SAMPLE_MAX_MB}MB"}), 413
    name = safe_name(request.form.get("name") or "SAGI My Voice")
    form = {
        "name": name,
        "description": "SAGI mobile voice clone",
        "remove_background_noise": "false",
    }
    try:
        with sample_path.open("rb") as fh:
            files = {"files": (sample.filename or "voice.m4a", fh, sample.mimetype or "audio/mp4")}
            r = requests.post(ELEVENLABS_BASE + "/v1/voices/add", headers=_eleven_headers(), data=form, files=files, timeout=120)
        if r.status_code >= 400:
            return jsonify({"ok": False, "error": "ELEVENLABS_CLONE: " + r.text[:500]}), 502
        out = r.json() or {}
        return jsonify({
            "ok": True,
            "voice_id": out.get("voice_id") or "",
            "requires_verification": bool(out.get("requires_verification")),
            "name": name,
        })
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)[:700]}), 500
    finally:
        shutil.rmtree(work, ignore_errors=True)
        gc.collect()

@app.post("/api/voice/preview")
def voice_preview():
    if not authorized():
        return jsonify({"ok": False, "error": "Unauthorized"}), 401
    data = request.get_json(silent=True) or {}
    text = str(data.get("text") or "").strip()
    mode = str(data.get("mode") or "ai_male")
    voice_id = str(data.get("voice_id") or "").strip()
    speed = float(data.get("speed") or 1.0)
    if not text:
        return jsonify({"ok": False, "error": "Text required"}), 400
    work = tempfile.mkdtemp(prefix="sagi_voice_preview_")
    path = Path(work) / "preview.mp3"
    try:
        synthesize_voice(text[:500], mode, voice_id, path, speed)
        resp = send_file(path, mimetype="audio/mpeg", as_attachment=False)
        resp.call_on_close(lambda: shutil.rmtree(work, ignore_errors=True))
        return resp
    except Exception as e:
        shutil.rmtree(work, ignore_errors=True)
        return jsonify({"ok": False, "error": str(e)[:700]}), 500

@app.post("/api/render")
def create_render_job():
    if not authorized():
        return jsonify({"ok": False, "error": "Unauthorized"}), 401
    upload = request.files.get("media")
    if not upload:
        return jsonify({"ok": False, "error": "Media file required"}), 400
    work = tempfile.mkdtemp(prefix="sagi_render_")
    suffix = Path(upload.filename or "source.mp4").suffix or ".mp4"
    source = Path(work) / ("source" + suffix)
    upload.save(source)
    size = source.stat().st_size if source.exists() else 0
    if size <= 0:
        shutil.rmtree(work, ignore_errors=True)
        return jsonify({"ok": False, "error": "Empty media"}), 400
    if size > RENDER_MAX_MB * 1024 * 1024:
        shutil.rmtree(work, ignore_errors=True)
        return jsonify({"ok": False, "error": f"Media exceeds {RENDER_MAX_MB}MB"}), 413

    try:
        captions = json.loads(request.form.get("captions") or "[]")
        if not isinstance(captions, list):
            captions = []
    except Exception:
        captions = []

    voice_upload = request.files.get("voice_audio")
    uploaded_voice = ""
    if voice_upload:
        vp = Path(work) / ("voice" + (Path(voice_upload.filename or "voice.m4a").suffix or ".m4a"))
        voice_upload.save(vp)
        uploaded_voice = str(vp)

    options = {
        "start": request.form.get("start") or "0",
        "duration": request.form.get("duration") or "15",
        "aspect": request.form.get("aspect") or "9:16",
        "quality": request.form.get("quality") or "fast",
        "captions": captions[:300],
        "narration": request.form.get("narration") or "",
        "voice_mode": request.form.get("voice_mode") or "none",
        "voice_id": request.form.get("voice_id") or "",
        "voice_speed": request.form.get("voice_speed") or "1",
        "original_volume": request.form.get("original_volume") or "0.25",
        "burn_subtitles": str(request.form.get("burn_subtitles") or "true").lower() in ("1", "true", "yes"),
        "uploaded_voice": uploaded_voice,
    }
    job_id = secrets.token_urlsafe(10)
    job = {
        "id": job_id, "status": "queued", "stage": "已上传 · 等待云端",
        "progress": 8, "created_at": iso(), "updated_at": iso(),
        "workdir": work, "source": str(source), "path": "",
        "download_key": secrets.token_urlsafe(18), "filename": "SAGI_CLOUD_RENDER.mp4",
        "size": 0, "error": "", "options": options,
    }
    with render_jobs_lock:
        render_jobs[job_id] = job
        _persist_render_jobs_locked()
    Thread(target=run_cloud_render, args=(job_id, options), daemon=True).start()
    return jsonify({"ok": True, "job": public_render_job(job)})

@app.get("/api/render-jobs/<job_id>")
def get_render_job(job_id):
    if not authorized():
        return jsonify({"ok": False, "error": "Unauthorized"}), 401
    with render_jobs_lock:
        job = render_jobs.get(job_id)
        if not job:
            return jsonify({"ok": False, "error": "Render job not found"}), 404
        return jsonify({"ok": True, "job": public_render_job(job)})

@app.get("/api/render-jobs/<job_id>/file")
def get_render_file(job_id):
    key = request.args.get("key") or ""
    with render_jobs_lock:
        job = render_jobs.get(job_id)
        if not job:
            return jsonify({"ok": False, "error": "Render job not found"}), 404
        if not key or key != job.get("download_key"):
            return jsonify({"ok": False, "error": "Invalid download key"}), 403
        if job.get("status") != "ready" or not job.get("path"):
            return jsonify({"ok": False, "error": "Render not ready"}), 409
        path = job["path"]
    if not Path(path).exists():
        return jsonify({"ok": False, "error": "Render expired"}), 410
    as_download = str(request.args.get("download") or "").lower() in ("1", "true", "yes")
    return send_file(path, as_attachment=as_download, download_name="SAGI_CLOUD_RENDER.mp4", mimetype="video/mp4", conditional=True)


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
        "version": APP_VERSION,
    })

def cobalt_base():
    if not COBALT_HOSTPORT:
        return ""
    if COBALT_HOSTPORT.startswith("http://") or COBALT_HOSTPORT.startswith("https://"):
        return COBALT_HOSTPORT.rstrip("/")
    return "http://" + COBALT_HOSTPORT.rstrip("/")

def _cobalt_pick_media(payload):
    status = payload.get("status")
    if status in ("tunnel", "redirect"):
        return payload.get("url"), payload.get("filename") or ""
    if status == "picker":
        items = payload.get("picker") or []
        videos = [x for x in items if x.get("type") in ("video", "gif") and x.get("url")]
        chosen = (videos or [x for x in items if x.get("url")])
        if chosen:
            item = chosen[0]
            return item.get("url"), ""
    if status == "error":
        err = payload.get("error") or {}
        code = err.get("code") or "cobalt_error"
        raise RuntimeError("COBALT_ERROR: " + str(code))
    if status == "local-processing":
        raise RuntimeError("COBALT_LOCAL_PROCESSING_UNSUPPORTED")
    raise RuntimeError("COBALT_INVALID_RESPONSE")

def run_cobalt_download(job_id, url, wanted_name):
    with jobs_lock:
        job = jobs.get(job_id)
        if not job:
            return
        job["status"] = "cobalt_processing"
        job["updated_at"] = iso()
        job["strategy"] = "cobalt"

    work = tempfile.mkdtemp(prefix=f"sagi_cobalt_{job_id}_")
    try:
        base = cobalt_base()
        if not base:
            raise RuntimeError("COBALT_NOT_CONFIGURED")

        r = requests.post(
            base + "/",
            headers={"Accept": "application/json", "Content-Type": "application/json"},
            json={
                "url": url,
                "videoQuality": "1080",
                "downloadMode": "auto",
                "filenameStyle": "basic",
                "alwaysProxy": True,
                "localProcessing": "disabled",
            },
            timeout=90,
        )
        if r.status_code == 429:
            raise RuntimeError("COBALT_RATE_LIMIT")
        r.raise_for_status()
        payload = r.json()
        media_url, cobalt_name = _cobalt_pick_media(payload)
        if not media_url:
            raise RuntimeError("COBALT_NO_MEDIA")

        with jobs_lock:
            job = jobs.get(job_id)
            if job:
                job["status"] = "cobalt_fetching"
                job["updated_at"] = iso()

        media_resp = requests.get(media_url, stream=True, timeout=180)
        media_resp.raise_for_status()
        content_type = (media_resp.headers.get("Content-Type") or "").lower()

        name = safe_name(wanted_name or cobalt_name or "SAGI_INS_VIDEO")
        if "." not in name:
            if "image/" in content_type:
                name += ".jpg"
            else:
                name += ".mp4"
        path = Path(work) / name

        total = 0
        max_bytes = MAX_FILE_MB * 1024 * 1024
        with path.open("wb") as f:
            for chunk in media_resp.iter_content(chunk_size=1024 * 256):
                if not chunk:
                    continue
                total += len(chunk)
                if total > max_bytes:
                    raise RuntimeError(f"视频超过云端限制 {MAX_FILE_MB}MB")
                f.write(chunk)

        if not path.exists() or path.stat().st_size == 0:
            raise RuntimeError("COBALT_EMPTY_FILE")

        with jobs_lock:
            job = jobs.get(job_id)
            if not job:
                shutil.rmtree(work, ignore_errors=True)
                return
            job.update({
                "status": "ready",
                "updated_at": iso(),
                "path": str(path),
                "workdir": work,
                "filename": name,
                "title": cobalt_name or name,
                "size": path.stat().st_size,
                "strategy": "cobalt",
                "error": "",
                "errorCode": "",
            })
    except Exception as e:
        shutil.rmtree(work, ignore_errors=True)
        msg = str(e)
        code = "cobalt_failed"
        if "COBALT_RATE_LIMIT" in msg:
            code = "cobalt_rate_limit"
        elif "COBALT_NOT_CONFIGURED" in msg:
            code = "cobalt_not_ready"
        with jobs_lock:
            job = jobs.get(job_id)
            if job:
                job.update({
                    "status": "failed",
                    "updated_at": iso(),
                    "strategy": "cobalt",
                    "error": msg[:700],
                    "errorCode": code,
                })

@app.post("/api/jobs")
def create_job():
    if not authorized():
        return jsonify({"ok": False, "error": "Unauthorized"}), 401
    if not rate_allowed():
        return jsonify({"ok": False, "error": "Hourly download limit reached"}), 429

    data = request.get_json(silent=True) or {}
    url = (data.get("url") or "").strip()
    name = safe_name(data.get("name") or "SAGI_VIDEO")

    if not allowed_social_url(url):
        return jsonify({
            "ok": False,
            "error": "当前仅支持 Instagram / YouTube / TikTok / X 链接。",
            "errorCode": "unsupported_source",
        }), 400

    job_id = secrets.token_urlsafe(9)
    job = {
        "id": job_id,
        "status": "queued",
        "created_at": iso(),
        "updated_at": iso(),
        "title": name,
        "source_url": url,
        "requested_name": name,
        "error": "",
        "errorCode": "",
        "size": 0,
        "worker": "",
        "strategy": "sagi_cloud",
        "download_key": secrets.token_urlsafe(18),
        "path": "",
        "workdir": "",
        "filename": "",
    }
    with jobs_lock:
        jobs[job_id] = job

    Thread(target=run_download, args=(job_id, url, name), daemon=True).start()
    return jsonify({"ok": True, "job": public_job(job), "phoneOnly": True, "engine": "sagi-cloud-download"}), 202


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
