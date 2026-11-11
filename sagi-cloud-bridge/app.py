from flask import Flask, request, jsonify, send_file, Response
from flask_cors import CORS
from urllib.parse import urlparse
from pathlib import Path
from threading import Thread, Lock
from datetime import datetime, timedelta, timezone
from concurrent.futures import ThreadPoolExecutor, as_completed
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
import sys
import math
import zipfile
import html as html_lib
import base64
import requests
from curl_cffi import requests as curl_requests
import yt_dlp
from yt_dlp.utils import DownloadError
from faster_whisper import WhisperModel
import imageio_ffmpeg

app = Flask(__name__)

ALLOWED_ORIGIN = (os.getenv("SAGI_ALLOWED_ORIGIN") or "https://suny820916.github.io").rstrip("/")
SERVER_SECRET = (os.getenv("SAGI_SERVER_SECRET") or os.getenv("SAGI_BRIDGE_TOKEN") or "").strip()
PORT = int(os.getenv("PORT") or "10000")
DEPLOY_REVISION = "2026-11-12-match-intelligence-diag-v101"
APP_VERSION = "3.9.4"
MAX_FILE_MB = int(os.getenv("SAGI_MAX_FILE_MB") or "300")
JOB_TTL_MIN = int(os.getenv("SAGI_JOB_TTL_MIN") or "30")
RATE_LIMIT_PER_HOUR = int(os.getenv("SAGI_RATE_LIMIT_PER_HOUR") or "20")
CAPTION_RATE_LIMIT_PER_HOUR = int(os.getenv("SAGI_CAPTION_RATE_LIMIT_PER_HOUR") or "180")
caption_rate_hits = {}
caption_rate_lock = Lock()
COBALT_HOSTPORT = (os.getenv("SAGI_COBALT_HOSTPORT") or "").strip()
INSTAGRAM_PROXY = (os.getenv("SAGI_INSTAGRAM_PROXY") or "").strip()
BTCH_BASE = (os.getenv("SAGI_BTCH_BASE") or "https://btch-downloader-api-green.vercel.app").strip().rstrip("/")
BTCH_TIMEOUT_SECONDS = max(5, min(25, int(os.getenv("SAGI_BTCH_TIMEOUT_SECONDS") or "12")))
TIKWM_BASE = "https://www.tikwm.com/api/"
FXTWITTER_BASE = "https://api.fxtwitter.com/2"
ENGINE_COOLDOWN_SECONDS = max(10, min(180, int(os.getenv("SAGI_ENGINE_COOLDOWN_SECONDS") or "45")))
FOOTBALL_DATA_TOKEN = (os.getenv("FOOTBALL_DATA_TOKEN") or "").strip()
API_FOOTBALL_KEY = (os.getenv("API_FOOTBALL_KEY") or "").strip()
SPORTMONKS_TOKEN = (os.getenv("SPORTMONKS_TOKEN") or "").strip()
OPENAI_API_KEY = (os.getenv("OPENAI_API_KEY") or "").strip()
OPENAI_BASE_URL = (os.getenv("OPENAI_BASE_URL") or "https://api.openai.com").strip().rstrip("/")
SAGI_LOCAL_AI_MODEL = (os.getenv("SAGI_LOCAL_AI_MODEL") or "gpt-6-luna").strip()
SAGI_LOCAL_AI_TIMEOUT = max(10, min(60, int(os.getenv("SAGI_LOCAL_AI_TIMEOUT") or "35")))
SAGI_LOCAL_AI_RATE_LIMIT_PER_HOUR = max(10, min(300, int(os.getenv("SAGI_LOCAL_AI_RATE_LIMIT_PER_HOUR") or "60")))
SAGI_LOCAL_VISUAL_MAX_MB = max(2, min(20, int(os.getenv("SAGI_LOCAL_VISUAL_MAX_MB") or "8")))
SAGI_LOCAL_IMAGE_MODEL = (os.getenv("SAGI_LOCAL_IMAGE_MODEL") or "gpt-image-2.6-flare").strip()
SAGI_LOCAL_IMAGE_QUALITY = (os.getenv("SAGI_LOCAL_IMAGE_QUALITY") or "medium").strip().lower()

SAGI_SUPABASE_URL = (os.getenv("SAGI_SUPABASE_URL") or "https://zgqrjuwltbnkgovtsccb.supabase.co").strip().rstrip("/")
SAGI_SUPABASE_KEY = (os.getenv("SAGI_SUPABASE_KEY") or "sb_publishable_bqROSu6ZQRdDW3DLazUCfg_4aYxldN8").strip()
SAGI_MARKET_WRITE_TOKEN = (os.getenv("SAGI_MARKET_WRITE_TOKEN") or (hmac.new(SERVER_SECRET.encode("utf-8"), b"sagi-market-inbox-v1", hashlib.sha256).hexdigest() if SERVER_SECRET else "")).strip()
SAGI_MARKET_INBOX_SLUG = ("market-inbox-" + hmac.new(SERVER_SECRET.encode("utf-8"), b"sagi-market-inbox-slug-v1", hashlib.sha256).hexdigest()[:24]) if SERVER_SECRET else ""
SAGI_MARKET_RATE_LIMIT_PER_HOUR = max(3, min(60, int(os.getenv("SAGI_MARKET_RATE_LIMIT_PER_HOUR") or "12")))
market_rate_hits = {}
market_rate_lock = Lock()
if SAGI_LOCAL_IMAGE_QUALITY not in ("low", "medium", "high"):
    SAGI_LOCAL_IMAGE_QUALITY = "medium"
local_ai_hits = {}
local_ai_rate_lock = Lock()
FOOTBALL_CACHE_SECONDS = max(30, min(900, int(os.getenv("SAGI_FOOTBALL_CACHE_SECONDS") or "180")))
FOOTBALL_COMPETITIONS = {
    "PL": {"name": "英超", "football_data": "PL", "espn": "eng.1", "api_football": "Premier League", "official": "https://www.premierleague.com/en/matches/premier-league/2026-27", "primary": True},
    "PD": {"name": "西甲", "football_data": "PD", "espn": "esp.1", "api_football": "La Liga", "official": "https://www.laliga.com/en-US/laliga-easports/results", "primary": True},
    "BL1": {"name": "德甲", "football_data": "BL1", "espn": "ger.1", "api_football": "Bundesliga", "official": "https://www.bundesliga.com/en/bundesliga/matchday", "primary": True},
    "SA": {"name": "意甲", "football_data": "SA", "espn": "ita.1", "api_football": "Serie A", "official": "https://en.legaseriea.it/serie-a/fixtures-results", "primary": True},
    "FL1": {"name": "法甲", "football_data": "FL1", "espn": "fra.1", "api_football": "Ligue 1", "official": "https://ligue1.com/en/competitions/ligue1mcdonalds/results?season=2026", "primary": True},
    "CL": {"name": "欧冠", "football_data": "CL", "espn": "uefa.champions", "api_football": "UEFA Champions League", "official": "https://www.uefa.com/uefachampionsleague/fixtures-results/", "primary": True},
    "FAC": {"name": "足总杯", "football_data": "FAC", "espn": "eng.fa", "api_football": "FA Cup", "official": "https://www.thefa.com/competitions/thefacup/fixtures", "primary": False},
    "CDR": {"name": "国王杯", "football_data": "CDR", "espn": "esp.copa_del_rey", "api_football": "Copa del Rey", "official": "https://rfef.es/es/competiciones/copa-del-rey", "primary": False},
    "DFB": {"name": "德国杯", "football_data": "DFB", "espn": "ger.dfb_pokal", "api_football": "DFB Pokal", "official": "https://www.dfb.de/maenner/wettbewerbe/dfb-pokal", "primary": False},
    "CI": {"name": "意大利杯", "football_data": "", "espn": "ita.coppa_italia", "api_football": "Coppa Italia", "official": "https://en.legaseriea.it/coppa-italia/fixtures-results", "primary": False},
    "CDF": {"name": "法国杯", "football_data": "", "espn": "fra.coupe_de_france", "api_football": "Coupe de France", "official": "https://www.fff.fr/competition/engagement/425352-coupe-de-france/phase/1/index.html", "primary": False},
}
football_cache = {}
football_cache_lock = Lock()

CORS(app, resources={r"/api/*": {"origins": [ALLOWED_ORIGIN]}, r"/health": {"origins": [ALLOWED_ORIGIN]}, r"/": {"origins": [ALLOWED_ORIGIN]}})

jobs = {}
jobs_lock = Lock()
rate_hits = {}
rate_lock = Lock()
pair_codes = {}
pair_lock = Lock()
worker_presence = {"last_seen": 0, "worker_id": ""}
engine_state = {}
engine_state_lock = Lock()

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

MATCH_INTELLIGENCE_LITE = False
MATCH_INTELLIGENCE_LITE_ERROR = ""
try:
    from match_intelligence_lite import create_match_intelligence_blueprint
    app.register_blueprint(
        create_match_intelligence_blueprint(
            heavy_slot=heavy_slot,
            allowed_origin=ALLOWED_ORIGIN,
        )
    )
    MATCH_INTELLIGENCE_LITE = True
except Exception as exc:
    MATCH_INTELLIGENCE_LITE_ERROR = str(exc)[:240]
    print("match intelligence init failed:", MATCH_INTELLIGENCE_LITE_ERROR, flush=True)

FFMPEG_THREADS = max(1, min(2, int(os.getenv("SAGI_FFMPEG_THREADS") or "1")))
STATE_DIR = Path(os.getenv("SAGI_STATE_DIR") or (Path(tempfile.gettempdir()) / "sagi_cloud_state"))
RENDER_STATE_FILE = STATE_DIR / "render_jobs.json"
voice_cache = {"at": 0.0, "voices": []}

VOICE_STYLE_PRESETS = {
    "football": {"stability": 0.34, "similarity": 0.80, "style": 0.42, "pitch": 4, "volume": 5},
    "natural": {"stability": 0.48, "similarity": 0.78, "style": 0.12, "pitch": 0, "volume": 0},
    "documentary": {"stability": 0.64, "similarity": 0.77, "style": 0.08, "pitch": -4, "volume": 0},
    "news": {"stability": 0.72, "similarity": 0.80, "style": 0.04, "pitch": 0, "volume": 2},
    "warm": {"stability": 0.54, "similarity": 0.82, "style": 0.22, "pitch": 2, "volume": 1},
}

EDGE_VOICE_MAP = {
    "edge-zh-yunjian": "zh-CN-YunjianNeural",
    "edge-zh-yunxi": "zh-CN-YunxiNeural",
    "edge-zh-yunyang": "zh-CN-YunyangNeural",
    "edge-zh-xiaoxiao": "zh-CN-XiaoxiaoNeural",
    "edge-zh-xiaoyi": "zh-CN-XiaoyiNeural",
}

def voice_style_settings(name):
    return VOICE_STYLE_PRESETS.get(str(name or "").strip().lower(), VOICE_STYLE_PRESETS["natural"])

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

def market_rate_allowed():
    key = request.headers.get("X-Forwarded-For", request.remote_addr or "unknown").split(",")[0].strip()
    cutoff = time.time() - 3600
    with market_rate_lock:
        arr = [t for t in market_rate_hits.get(key, []) if t >= cutoff]
        if len(arr) >= SAGI_MARKET_RATE_LIMIT_PER_HOUR:
            market_rate_hits[key] = arr
            return False
        arr.append(time.time())
        market_rate_hits[key] = arr
    return True


def market_cloud_ready():
    return bool(SAGI_SUPABASE_URL and SAGI_SUPABASE_KEY and SAGI_MARKET_WRITE_TOKEN)


def _market_rpc(name, args):
    if not market_cloud_ready():
        raise RuntimeError("MARKET_CLOUD_NOT_CONFIGURED")
    r = requests.post(
        SAGI_SUPABASE_URL + "/rest/v1/rpc/" + name,
        headers={
            "Content-Type": "application/json",
            "apikey": SAGI_SUPABASE_KEY,
        },
        json=args,
        timeout=(5, 18),
    )
    if not r.ok:
        text = (r.text or "")[:600]
        raise RuntimeError("MARKET_RPC_" + str(r.status_code) + ": " + text)
    return r.json() if r.text else None


def _market_get(slug):
    if not (SAGI_SUPABASE_URL and SAGI_SUPABASE_KEY):
        raise RuntimeError("MARKET_SUPABASE_NOT_CONFIGURED")
    r = requests.post(
        SAGI_SUPABASE_URL + "/rest/v1/rpc/sagi_get_event",
        headers={
            "Content-Type": "application/json",
            "apikey": SAGI_SUPABASE_KEY,
        },
        json={"p_slug": slug},
        timeout=(5, 18),
    )
    if not r.ok:
        raise RuntimeError("MARKET_GET_" + str(r.status_code) + ": " + (r.text or "")[:500])
    return r.json() if r.text else None


def _market_ensure_inbox():
    row = _market_get(SAGI_MARKET_INBOX_SLUG)
    if row:
        return row
    return _market_rpc(
        "sagi_claim_event",
        {
            "p_slug": SAGI_MARKET_INBOX_SLUG,
            "p_token": SAGI_MARKET_WRITE_TOKEN,
            "p_payload": {"version": 1, "items": []},
        },
    )


def _market_update_inbox(mutator):
    last_error = None
    for _ in range(5):
        try:
            row = _market_ensure_inbox()
            payload = dict((row or {}).get("payload") or {})
            items = list(payload.get("items") or [])
            new_items = mutator(items)
            payload["version"] = 1
            payload["items"] = new_items[-500:]
            return _market_rpc(
                "sagi_save_event",
                {
                    "p_slug": SAGI_MARKET_INBOX_SLUG,
                    "p_token": SAGI_MARKET_WRITE_TOKEN,
                    "p_payload": payload,
                    "p_expected_revision": (row or {}).get("revision"),
                },
            )
        except Exception as exc:
            last_error = exc
            if "REVISION_CONFLICT" not in str(exc):
                break
            time.sleep(0.08)
    raise last_error or RuntimeError("MARKET_INBOX_UPDATE_FAILED")


def _market_clean_text(value, limit):
    return str(value or "").strip()[:limit]


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


def source_platform(url):
    host = _url_host(url)
    if host == "instagram.com" or host.endswith(".instagram.com"):
        return "instagram"
    if host == "tiktok.com" or host.endswith(".tiktok.com"):
        return "tiktok"
    if host in ("x.com", "twitter.com") or host.endswith(".x.com") or host.endswith(".twitter.com"):
        return "twitter"
    if host in ("youtube.com", "youtu.be") or host.endswith(".youtube.com"):
        return "youtube"
    return ""


def _engine_can_try(name):
    with engine_state_lock:
        row = engine_state.get(name) or {}
        return float(row.get("open_until") or 0) <= time.time()


def _engine_result(name, ok, error=""):
    with engine_state_lock:
        row = dict(engine_state.get(name) or {})
        if ok:
            row.update({"fails": 0, "open_until": 0, "last_error": "", "last_ok": iso()})
        else:
            fails = int(row.get("fails") or 0) + 1
            row.update({"fails": fails, "last_error": str(error)[:180], "last_fail": iso()})
            if fails >= 2:
                row["open_until"] = time.time() + ENGINE_COOLDOWN_SECONDS
        engine_state[name] = row


def _set_job_engine(job_id, engine, switching=False):
    with jobs_lock:
        job = jobs.get(job_id)
        if not job:
            return
        trace = list(job.get("engineTrace") or [])
        if not trace or trace[-1] != engine:
            trace.append(engine)
        job["engineTrace"] = trace[-8:]
        job["strategy"] = engine
        job["status"] = "router_switching" if switching else "router_trying"
        job["updated_at"] = iso()


def _media_extension(kind, content_type="", url=""):
    low = str(content_type or "").lower()
    path = urlparse(str(url or "")).path.lower()
    if kind in ("video", "gif") or "video/" in low:
        if path.endswith(".webm"):
            return ".webm"
        return ".mp4"
    if "png" in low or path.endswith(".png"):
        return ".png"
    if "webp" in low or path.endswith(".webp"):
        return ".webp"
    return ".jpg"


def _save_remote_items(job_id, items, wanted_name, strategy, title=""):
    clean_items = []
    seen = set()
    for raw in items or []:
        u = str((raw or {}).get("url") or "").strip()
        kind = str((raw or {}).get("type") or (raw or {}).get("kind") or "video").lower()
        if not u.startswith(("http://", "https://")) or u in seen:
            continue
        seen.add(u)
        clean_items.append({"url": u, "type": kind})
        if len(clean_items) >= 20:
            break
    if not clean_items:
        raise RuntimeError(strategy.upper() + "_NO_MEDIA")

    work = tempfile.mkdtemp(prefix=f"sagi_router_{strategy}_{job_id}_")
    saved = []
    total = 0
    max_bytes = MAX_FILE_MB * 1024 * 1024
    try:
        for idx, item in enumerate(clean_items, start=1):
            media_url = item["url"]
            headers = {
                "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1",
                "Accept": "*/*",
            }
            low = media_url.lower()
            if "cdninstagram.com" in low or "fbcdn.net" in low:
                headers["Referer"] = "https://www.instagram.com/"
            elif "tiktok" in low or "tikwm" in low:
                headers["Referer"] = "https://www.tiktok.com/"
            elif "twimg.com" in low:
                headers["Referer"] = "https://x.com/"
            r = requests.get(media_url, headers=headers, stream=True, timeout=(7, 60), allow_redirects=True)
            r.raise_for_status()
            ctype = (r.headers.get("Content-Type") or "").lower()
            if "text/html" in ctype or "application/json" in ctype:
                raise RuntimeError(strategy.upper() + "_NON_MEDIA_RESPONSE")
            ext = _media_extension(item["type"], ctype, media_url)
            p = Path(work) / f"{idx:02d}{ext}"
            size = 0
            with p.open("wb") as out:
                for chunk in r.iter_content(chunk_size=256 * 1024):
                    if not chunk:
                        continue
                    size += len(chunk)
                    total += len(chunk)
                    if total > max_bytes:
                        raise RuntimeError(f"媒体超过云端限制 {MAX_FILE_MB}MB")
                    out.write(chunk)
            if size > 0:
                saved.append((item["type"], p))

        if not saved:
            raise RuntimeError(strategy.upper() + "_EMPTY_FILE")

        base_name = safe_name(wanted_name or "SAGI_VIDEO")
        if len(saved) == 1:
            kind, src = saved[0]
            filename = base_name if "." in base_name else base_name + src.suffix
            dst = Path(work) / filename
            if src.resolve() != dst.resolve():
                src.replace(dst)
            final_path = dst
            media_kind = "video" if kind in ("video", "gif") else "image"
            count = 1
        else:
            filename = base_name + "_MEDIA.zip"
            final_path = Path(work) / filename
            with zipfile.ZipFile(final_path, "w", compression=zipfile.ZIP_STORED) as zf:
                for idx, (_, src) in enumerate(saved, start=1):
                    zf.write(src, arcname=f"{idx:02d}{src.suffix}")
            for _, src in saved:
                src.unlink(missing_ok=True)
            media_kind = "carousel"
            count = len(saved)

        with jobs_lock:
            job = jobs.get(job_id)
            if not job:
                shutil.rmtree(work, ignore_errors=True)
                return False
            job.update({
                "status": "ready",
                "updated_at": iso(),
                "path": str(final_path),
                "workdir": work,
                "filename": filename,
                "title": title or filename,
                "size": final_path.stat().st_size,
                "strategy": strategy,
                "mediaKind": media_kind,
                "fileCount": count,
                "error": "",
                "errorCode": "",
            })
        return True
    except Exception:
        shutil.rmtree(work, ignore_errors=True)
        raise


def _btch_media(payload):
    normalized = (payload or {}).get("normalized") or {}
    rows = []
    if normalized.get("kind") == "media":
        rows = normalized.get("media") or []
    elif normalized.get("kind") == "list":
        for item in normalized.get("items") or []:
            if isinstance(item, dict):
                rows.extend(item.get("media") or [])
    items = []
    for row in rows:
        if not isinstance(row, dict):
            continue
        u = row.get("url")
        kind = str(row.get("type") or "video").lower()
        if kind not in ("video", "image", "photo", "gif"):
            continue
        if u:
            items.append({"url": u, "type": "image" if kind in ("image", "photo") else kind})
    return items, str(normalized.get("title") or (payload or {}).get("title") or "")


def run_btch_download(job_id, url, wanted_name):
    platform = source_platform(url)
    if platform not in ("instagram", "tiktok", "twitter", "youtube"):
        raise RuntimeError("BTCH_UNSUPPORTED")
    r = requests.get(
        BTCH_BASE + "/api/download/" + platform,
        params={"url": url},
        headers={"Accept": "application/json", "User-Agent": "SAGI-DOWN/3.0"},
        timeout=(5, BTCH_TIMEOUT_SECONDS),
    )
    if r.status_code == 429:
        raise RuntimeError("BTCH_RATE_LIMIT")
    r.raise_for_status()
    payload = r.json()
    if not payload.get("success", True):
        raise RuntimeError("BTCH_UPSTREAM_FAILED")
    items, title = _btch_media(payload)
    return _save_remote_items(job_id, items, wanted_name, "btch", title)


def run_parth_download(job_id, url, wanted_name):
    # Keep this extractor hard-bounded. Instagram can make logged-out clients
    # retry several endpoints; a subprocess lets us kill the attempt cleanly.
    script = r"""
import json, sys
from parth_dl import get_info
print(json.dumps(get_info(sys.argv[1], verbose=False), ensure_ascii=False))
"""
    try:
        proc = subprocess.run(
            [sys.executable, "-c", script, url],
            capture_output=True,
            text=True,
            timeout=16,
            check=False,
        )
    except subprocess.TimeoutExpired:
        raise RuntimeError("PARTH_DL_TIMEOUT")
    if proc.returncode != 0:
        raise RuntimeError("PARTH_DL_FAILED: " + (proc.stderr or "")[-300:])
    try:
        info = json.loads((proc.stdout or "").strip())
    except Exception:
        raise RuntimeError("PARTH_DL_INVALID_JSON")

    items = []
    for entry in info.get("entries") or []:
        formats = [x for x in (entry.get("formats") or []) if x.get("url")]
        if not formats:
            continue
        def score(x):
            area = int(x.get("width") or 0) * int(x.get("height") or 0)
            return (1 if x.get("has_audio") else 0, area)
        best = max(formats, key=score)
        items.append({"url": best["url"], "type": entry.get("kind") or "video"})
    return _save_remote_items(job_id, items, wanted_name, "parth-dl", info.get("title") or "")

def run_tikwm_download(job_id, url, wanted_name):
    r = requests.post(
        TIKWM_BASE,
        data={"url": url},
        headers={"User-Agent": "SAGI-DOWN/3.0", "Accept": "application/json"},
        timeout=(5, 18),
    )
    r.raise_for_status()
    payload = r.json() or {}
    if int(payload.get("code") or -1) != 0 or not payload.get("data"):
        raise RuntimeError("TIKWM_FAILED: " + str(payload.get("msg") or "unknown"))
    data = payload["data"]
    items = []
    for u in data.get("images") or []:
        if u:
            items.append({"url": u, "type": "image"})
    if not items:
        video = data.get("hdplay") or data.get("play") or data.get("wmplay")
        if video:
            items.append({"url": video, "type": "video"})
    return _save_remote_items(job_id, items, wanted_name, "tikwm", data.get("title") or "")


def _fxtwitter_items(payload):
    found = []
    seen = set()

    def add(kind, url, score=0):
        u = str(url or "").strip()
        if not u.startswith(("http://", "https://")) or u in seen:
            return
        seen.add(u)
        found.append({"type": kind, "url": u, "_score": score})

    def walk(obj):
        if isinstance(obj, dict):
            video_info = obj.get("video_info")
            if isinstance(video_info, dict):
                variants = []
                for v in video_info.get("variants") or []:
                    if isinstance(v, dict) and str(v.get("content_type") or "").startswith("video/mp4") and v.get("url"):
                        variants.append(v)
                if variants:
                    best = max(variants, key=lambda x: int(x.get("bitrate") or 0))
                    add("video", best.get("url"), int(best.get("bitrate") or 0))
                    return
            if obj.get("__typename") == "ApiImage" and obj.get("original_img_url"):
                add("image", obj.get("original_img_url"))
            elif str(obj.get("type") or "").lower() in ("photo", "image") and obj.get("media_url_https"):
                add("image", obj.get("media_url_https"))
            for value in obj.values():
                walk(value)
        elif isinstance(obj, list):
            for value in obj:
                walk(value)

    walk((payload or {}).get("status") or payload)
    return [{k: v for k, v in row.items() if k != "_score"} for row in found]


def run_fxtwitter_download(job_id, url, wanted_name):
    m = re.search(r"/status/(\d+)", url)
    if not m:
        raise RuntimeError("FXTWITTER_INVALID_URL")
    status_id = m.group(1)
    r = requests.get(
        FXTWITTER_BASE + "/status/" + status_id,
        headers={"Accept": "application/json", "User-Agent": "SAGI-DOWN/3.0"},
        timeout=(5, 15),
    )
    r.raise_for_status()
    payload = r.json() or {}
    if int(payload.get("code") or 200) >= 400:
        raise RuntimeError("FXTWITTER_FAILED")
    items = _fxtwitter_items(payload)
    title = str(((payload.get("status") or {}).get("text") or ""))[:100]
    return _save_remote_items(job_id, items, wanted_name, "fxtwitter", title)


def _router_engines(platform):
    return {
        "instagram": ["btch", "parth-dl"],
        "tiktok": ["btch", "tikwm"],
        "twitter": ["fxtwitter", "btch"],
        "youtube": [],
    }.get(platform, [])


def run_router_engine(job_id, engine, url, wanted_name):
    _set_job_engine(job_id, engine, switching=True)
    if not _engine_can_try(engine):
        with jobs_lock:
            job = jobs.get(job_id)
            if job:
                job["lastEngineError"] = engine.upper() + "_CIRCUIT_OPEN"
        return False
    try:
        if engine == "btch":
            ok = run_btch_download(job_id, url, wanted_name)
        elif engine == "parth-dl":
            ok = run_parth_download(job_id, url, wanted_name)
        elif engine == "tikwm":
            ok = run_tikwm_download(job_id, url, wanted_name)
        elif engine == "fxtwitter":
            ok = run_fxtwitter_download(job_id, url, wanted_name)
        else:
            raise RuntimeError("UNKNOWN_ENGINE")
        _engine_result(engine, bool(ok))
        return bool(ok)
    except Exception as e:
        _engine_result(engine, False, e)
        with jobs_lock:
            job = jobs.get(job_id)
            if job:
                job["status"] = "router_switching"
                job["updated_at"] = iso()
                job["lastEngineError"] = str(e)[:220]
        return False


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
        "voiceComplete": bool(job.get("voiceComplete", False)),
        "voiceCoverage": int(job.get("voiceCoverage", 0) or 0),
        "voiceSegments": int(job.get("voiceSegments", 0) or 0),
        "voiceDuration": float(job.get("voiceDuration", 0) or 0),
        "voiceTimeline": list(job.get("voiceTimeline") or [])[:120],
        "visualSyncStrategy": str(job.get("visualSyncStrategy") or ""),
        "visualStretchFactor": float(job.get("visualStretchFactor", 1) or 1),
        "visualGap": float(job.get("visualGap", 0) or 0),
        "visualHoldSeconds": float(job.get("visualHoldSeconds", 0) or 0),
        "meaningFirst": bool(job.get("meaningFirst", False)),
        "meaningCoverage": int(job.get("meaningCoverage", 0) or 0),
        "sceneSyncSegments": int(job.get("sceneSyncSegments", 0) or 0),
        "sceneSyncInstances": int(job.get("sceneSyncInstances", 0) or 0),
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

def synthesize_eleven(text, voice_id, output_path, speed=1.0, style="natural"):
    if not text.strip():
        raise RuntimeError("EMPTY_NARRATION")
    voice_id = voice_id.strip()
    if not voice_id:
        raise RuntimeError("VOICE_ID_REQUIRED")
    cfg = voice_style_settings(style)
    payload = {
        "text": text[:10000],
        "model_id": "eleven_flash_v2_5",
        "voice_settings": {
            "stability": cfg["stability"],
            "similarity_boost": cfg["similarity"],
            "style": cfg["style"],
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


def synthesize_edge_tts(text, mode, output_path, speed=1.0, style="natural", explicit_voice=""):
    if not str(text or "").strip():
        raise RuntimeError("EMPTY_NARRATION")
    try:
        import asyncio
        import edge_tts
        cfg = voice_style_settings(style)
        voice = EDGE_VOICE_MAP.get(str(explicit_voice or "").strip())
        if not voice:
            voice = "zh-CN-YunjianNeural" if mode == "ai_male" else "zh-CN-XiaoxiaoNeural"
        rate = int(round((max(0.75, min(1.25, float(speed or 1.0))) - 1.0) * 100))
        pitch = int(cfg.get("pitch") or 0)
        volume = int(cfg.get("volume") or 0)
        async def _save():
            communicate = edge_tts.Communicate(
                str(text)[:10000],
                voice=voice,
                rate=f"{rate:+d}%",
                pitch=f"{pitch:+d}Hz",
                volume=f"{volume:+d}%",
            )
            await communicate.save(str(output_path))
        asyncio.run(_save())
        if not Path(output_path).exists() or Path(output_path).stat().st_size < 1000:
            raise RuntimeError("EDGE_TTS_EMPTY_AUDIO")
        return str(output_path)
    except Exception as e:
        raise RuntimeError("EDGE_TTS: " + str(e)[:500])


def synthesize_voice(text, mode, voice_id, output_path, speed=1.0, style="natural"):
    mode = str(mode or "ai_male")
    voice_id = str(voice_id or "").strip()
    if voice_id in EDGE_VOICE_MAP:
        edge_mode = "ai_female" if voice_id in ("edge-zh-xiaoxiao", "edge-zh-xiaoyi") else "ai_male"
        return synthesize_edge_tts(text, edge_mode, output_path, speed, style, voice_id)
    if mode == "clone":
        if not ELEVENLABS_API_KEY:
            raise RuntimeError("VOICE_CLONE_REQUIRES_ELEVENLABS")
        selected = resolve_voice_id(mode, voice_id)
        return synthesize_eleven(text, selected, output_path, speed, style)

    # Premium path first; generic AI voices fall back automatically to keyless Edge Neural.
    if ELEVENLABS_API_KEY:
        try:
            selected = resolve_voice_id(mode, voice_id)
            return synthesize_eleven(text, selected, output_path, speed, style)
        except Exception as e:
            print("ElevenLabs generic TTS fallback:", str(e)[:300], flush=True)

    return synthesize_edge_tts(text, mode, output_path, speed, style, voice_id)


def audio_duration_seconds(path):
    try:
        import av
        with av.open(str(path), metadata_errors="ignore") as container:
            if getattr(container, "duration", None):
                return max(0.0, float(container.duration) / 1000000.0)
            for stream in container.streams.audio:
                if stream.duration is not None and stream.time_base is not None:
                    return max(0.0, float(stream.duration * stream.time_base))
    except TypeError:
        try:
            import av
            with av.open(str(path)) as container:
                if getattr(container, "duration", None):
                    return max(0.0, float(container.duration) / 1000000.0)
        except Exception:
            pass
    except Exception:
        pass
    return 0.0


def _atempo_chain(rate):
    rate = max(0.1, min(8.0, float(rate or 1.0)))
    parts = []
    while rate > 2.0:
        parts.append(2.0)
        rate /= 2.0
    while rate < 0.5:
        parts.append(0.5)
        rate /= 0.5
    parts.append(rate)
    return ",".join(f"atempo={x:.5f}" for x in parts)


def fit_narration_to_duration(source_path, work, target_duration, output_name="narration_fit.m4a"):
    """
    Fit narration toward the clip duration WITHOUT ever cutting the ending.
    We only apply a natural speed-up ceiling. If speech is still longer,
    the renderer extends the video's final frame so every word is preserved.
    """
    target = max(0.8, float(target_duration or 0))
    actual = audio_duration_seconds(source_path)
    if actual <= 0.1:
        return Path(source_path)
    ratio = actual / target
    if ratio <= 1.015:
        return Path(source_path)

    # Avoid chipmunk / rushed speech. Anything beyond this is handled by
    # extending the video tail instead of truncating narration.
    applied_rate = min(ratio, 1.18)
    if applied_rate <= 1.015:
        return Path(source_path)

    out = Path(work) / str(output_name or "narration_fit.m4a")
    exe = imageio_ffmpeg.get_ffmpeg_exe()
    af = _atempo_chain(applied_rate)
    cmd = [
        exe, "-hide_banner", "-loglevel", "error", "-y",
        "-i", str(source_path), "-vn", "-filter:a", af,
        "-c:a", "aac", "-b:a", "160k", str(out),
    ]
    proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=90)
    if proc.returncode != 0 or not out.exists() or out.stat().st_size < 1000:
        print("voice sync fallback:", (proc.stdout or "")[-500:], flush=True)
        return Path(source_path)
    return out


def _voice_compact_text(text):
    return re.sub(r"\s+", "", str(text or ""))


def split_voice_sentences(text, max_chars=140):
    """Split narration without losing any spoken characters."""
    raw = str(text or "").replace("\r\n", "\n").replace("\r", "\n").strip()
    if not raw:
        return []
    max_chars = max(40, min(280, int(max_chars or 140)))
    chunks, buf = [], ""
    strong = set("。！？!?；;\n")
    soft = set("，、,:：")
    last_soft = -1
    for ch in raw:
        buf += ch
        if ch in soft:
            last_soft = len(buf)
        should_flush = ch in strong
        if len(buf) >= max_chars:
            if last_soft >= max(20, int(max_chars * 0.55)):
                head, tail = buf[:last_soft], buf[last_soft:]
                if head.strip():
                    chunks.append(head.strip())
                buf = tail
            else:
                if buf.strip():
                    chunks.append(buf.strip())
                buf = ""
            last_soft = -1
            continue
        if should_flush and buf.strip():
            chunks.append(buf.strip())
            buf = ""
            last_soft = -1
    if buf.strip():
        chunks.append(buf.strip())
    return [x for x in chunks if x]


def build_voice_timeline(text, clip_duration=0):
    parts = split_voice_sentences(text)
    if not parts:
        return []
    weights = []
    for part in parts:
        chars = max(1, len(re.findall(r"[\u3400-\u9fffA-Za-z0-9]", part)))
        marks = len(re.findall(r"[，。！？；：、,.!?;:]", part))
        weights.append(max(1.0, chars + marks * 1.8))
    natural_total = sum(
        max(0.7, len(re.findall(r"[\u3400-\u9fffA-Za-z0-9]", p)) / 4.25
            + len(re.findall(r"[，。！？；：、,.!?;:]", p)) * 0.08)
        for p in parts
    )
    target_total = max(natural_total, float(clip_duration or 0))
    gap = 0.08
    usable = max(len(parts) * 0.7, target_total - gap * max(0, len(parts) - 1))
    total_weight = max(1.0, sum(weights))
    rows, cursor = [], 0.0
    for i, (part, weight) in enumerate(zip(parts, weights)):
        slot = max(0.7, usable * weight / total_weight)
        rows.append({"index": i, "text": part, "start": round(cursor, 3), "end": round(cursor + slot, 3)})
        cursor += slot + (gap if i < len(parts) - 1 else 0)
    return rows


def normalize_voice_timeline(raw_timeline, narration, clip_duration=0):
    expected = _voice_compact_text(narration)
    rows = []
    if isinstance(raw_timeline, list):
        for i, item in enumerate(raw_timeline[:120]):
            if not isinstance(item, dict):
                continue
            text = str(item.get("text") or "").strip()
            if not text:
                continue
            try:
                start = max(0.0, float(item.get("start") or 0))
                end = max(start + 0.1, float(item.get("end") or start + 0.1))
            except Exception:
                continue
            rows.append({"index": len(rows), "text": text, "start": start, "end": end})
    # Never trust a client timeline that omits/reorders narration.
    if not rows or _voice_compact_text("".join(x["text"] for x in rows)) != expected:
        rows = build_voice_timeline(narration, clip_duration)
    if _voice_compact_text("".join(x["text"] for x in rows)) != expected:
        raise RuntimeError("VOICE_TIMELINE_TEXT_MISMATCH")
    return rows


def synthesize_voice_timeline(narration, mode, voice_id, work, speed=1.0, style="natural",
                              clip_duration=0, raw_timeline=None, sync_mode="fit"):
    """
    VOICE DIRECTOR V1.2:
    synthesize every sentence independently, validate every segment, then place
    segments on a narration timeline. No input sentence is allowed to disappear.
    """
    narration = str(narration or "").strip()
    timeline = normalize_voice_timeline(raw_timeline, narration, clip_duration)
    if not timeline:
        raise RuntimeError("EMPTY_NARRATION")

    exe = imageio_ffmpeg.get_ffmpeg_exe()
    inputs, filter_parts, actual_rows = [], [], []
    cursor = 0.0
    spoken_chars = 0
    for i, row in enumerate(timeline):
        text = str(row["text"]).strip()
        seg_path = Path(work) / f"voice_seg_{i:03d}.mp3"
        synthesize_voice(text, mode, voice_id, seg_path, speed, style)
        seg_duration = audio_duration_seconds(seg_path)
        char_count = len(re.findall(r"[\u3400-\u9fffA-Za-z0-9]", text))
        # Very permissive sanity floor: catches empty/provider-truncated segments.
        min_reasonable = max(0.12, char_count / 15.0)
        if seg_duration < min_reasonable:
            raise RuntimeError(f"VOICE_SEGMENT_INCOMPLETE_{i+1}")

        target_slot = max(0.7, float(row["end"]) - float(row["start"]))
        fitted = seg_path
        if str(sync_mode or "fit") == "fit" and seg_duration > target_slot * 1.015:
            fitted = fit_narration_to_duration(
                seg_path, work, target_slot,
                output_name=f"voice_seg_{i:03d}_fit.m4a",
            )
            seg_duration = audio_duration_seconds(fitted)
            if seg_duration <= 0.1:
                raise RuntimeError(f"VOICE_SEGMENT_FIT_FAILED_{i+1}")

        desired_start = max(0.0, float(row["start"]))
        actual_start = desired_start if i == 0 else max(desired_start, cursor + 0.06)
        actual_end = actual_start + seg_duration
        cursor = actual_end
        spoken_chars += char_count
        inputs += ["-i", str(fitted)]
        delay_ms = max(0, int(round(actual_start * 1000)))
        filter_parts.append(f"[{i}:a]asetpts=PTS-STARTPTS,adelay={delay_ms}:all=1[a{i}]")
        actual_rows.append({
            "index": i,
            "text": text,
            "targetStart": round(desired_start, 3),
            "targetEnd": round(float(row["end"]), 3),
            "start": round(actual_start, 3),
            "end": round(actual_end, 3),
            "duration": round(seg_duration, 3),
        })

    expected_compact = _voice_compact_text(narration)
    actual_compact = _voice_compact_text("".join(x["text"] for x in actual_rows))
    if not expected_compact or actual_compact != expected_compact:
        raise RuntimeError("VOICE_COMPLETENESS_GUARD_FAILED")

    out = Path(work) / "narration_timeline.m4a"
    labels = "".join(f"[a{i}]" for i in range(len(actual_rows)))
    filter_parts.append(f"{labels}amix=inputs={len(actual_rows)}:duration=longest:normalize=0[aout]")
    cmd = [
        exe, "-hide_banner", "-loglevel", "error", "-y", *inputs,
        "-filter_complex", ";".join(filter_parts),
        "-map", "[aout]", "-c:a", "aac", "-b:a", "160k", str(out),
    ]
    proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=180)
    if proc.returncode != 0 or not out.exists() or out.stat().st_size < 1000:
        raise RuntimeError("VOICE_TIMELINE_MIX_FAILED: " + (proc.stdout or "")[-500:])

    final_duration = audio_duration_seconds(out)
    if final_duration + 0.08 < actual_rows[-1]["end"]:
        raise RuntimeError("VOICE_FINAL_AUDIO_TRUNCATED")
    meta = {
        "complete": True,
        "coverage": 100,
        "segments": len(actual_rows),
        "chars": spoken_chars,
        "duration": round(final_duration, 3),
        "timeline": actual_rows,
    }
    return out, meta


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

def normalize_scene_plan(raw_plan, clip_duration, output_duration):
    rows = []
    if not isinstance(raw_plan, list):
        return rows
    for item in raw_plan[:60]:
        if not isinstance(item, dict):
            continue
        try:
            ss = max(0.0, min(float(clip_duration), float(item.get("sourceStart") or 0)))
            se = max(ss + 0.08, min(float(clip_duration), float(item.get("sourceEnd") or ss + 0.08)))
            os_ = max(0.0, float(item.get("outputStart") or 0))
            oe = max(os_ + 0.08, float(item.get("outputEnd") or os_ + 0.08))
        except Exception:
            continue
        if se - ss < 0.08:
            continue
        rows.append({
            "sceneId": int(item.get("sceneId") or 0),
            "sourceStart": ss,
            "sourceEnd": se,
            "outputStart": os_,
            "outputEnd": oe,
            "label": str(item.get("label") or "")[:80],
            "matchScore": float(item.get("matchScore") or 0),
        })
    if not rows:
        return []
    rows.sort(key=lambda x: (x["outputStart"], x["outputEnd"]))
    weights = [max(0.08, x["outputEnd"] - x["outputStart"]) for x in rows]
    total_weight = max(0.08, sum(weights))
    out = []
    cursor = 0.0
    for i, (row, weight) in enumerate(zip(rows, weights)):
        start = cursor
        seg_duration = float(output_duration) * weight / total_weight
        end = min(float(output_duration), start + max(0.08, seg_duration))
        if i == len(rows) - 1:
            end = float(output_duration)
        if start >= output_duration - 0.02:
            break
        x = dict(row)
        x["outputStart"] = start
        x["outputEnd"] = end
        out.append(x)
        cursor = end
    return out


def expand_scene_instances(scene_plan, max_stretch=1.65, max_instances=80):
    instances = []
    for row in scene_plan:
        src_dur = max(0.08, row["sourceEnd"] - row["sourceStart"])
        out_dur = max(0.08, row["outputEnd"] - row["outputStart"])
        repeats = max(1, int(math.ceil(out_dur / max(0.08, src_dur * max_stretch))))
        repeats = min(6, repeats)
        per_out = out_dur / repeats
        factor = max(0.08, per_out / src_dur)
        for r in range(repeats):
            instances.append({
                "sceneId": row["sceneId"],
                "sourceStart": row["sourceStart"],
                "sourceEnd": row["sourceEnd"],
                "duration": per_out,
                "factor": factor,
                "repeatIndex": r,
                "repeatCount": repeats,
            })
            if len(instances) >= max_instances:
                return instances
    return instances


def remap_captions_to_scene_plan(captions, scene_plan):
    mapped = []
    for row in scene_plan:
        ss, se = row["sourceStart"], row["sourceEnd"]
        os_, oe = row["outputStart"], row["outputEnd"]
        src_dur = max(0.08, se - ss)
        out_dur = max(0.08, oe - os_)
        for cap in captions or []:
            try:
                cs = float(cap.get("start") or 0)
                ce = float(cap.get("end") or cs + 0.5)
            except Exception:
                continue
            if ce <= ss or cs >= se:
                continue
            start_ratio = max(0.0, min(1.0, (max(cs, ss) - ss) / src_dur))
            end_ratio = max(start_ratio + 0.01, min(1.0, (min(ce, se) - ss) / src_dur))
            mapped.append({
                "start": os_ + start_ratio * out_dur,
                "end": min(oe, os_ + end_ratio * out_dur),
                "text": str(cap.get("text") or ""),
            })
    mapped.sort(key=lambda x: (x["start"], x["end"]))
    return mapped[:500]


def build_semantic_video_filters(instances, width, height):
    parts, labels = [], []
    zw = max(width + 2, int(round(width * 1.05 / 2.0) * 2))
    zh = max(height + 2, int(round(height * 1.05 / 2.0) * 2))
    for i, inst in enumerate(instances):
        ss, se = inst["sourceStart"], inst["sourceEnd"]
        factor = max(0.08, float(inst.get("factor") or 1))
        chain = (
            f"[0:v]trim=start={ss:.4f}:end={se:.4f},setpts=PTS-STARTPTS,"
            f"scale={width}:{height}:force_original_aspect_ratio=increase,"
            f"crop={width}:{height},setsar=1"
        )
        if abs(factor - 1.0) > 0.005:
            chain += f",setpts={factor:.8f}*PTS"
        if factor > 1.03:
            phase = i % 4
            if phase == 0:
                xexpr, yexpr = "(iw-ow)/2*(1+sin(t*0.25))", "(ih-oh)/2"
            elif phase == 1:
                xexpr, yexpr = "(iw-ow)/2", "(ih-oh)/2*(1+cos(t*0.21))"
            elif phase == 2:
                xexpr, yexpr = "(iw-ow)/2*(1+cos(t*0.19))", "(ih-oh)/2*(1+sin(t*0.17))"
            else:
                xexpr, yexpr = "(iw-ow)/2*(1+sin(t*0.16))", "(ih-oh)/2*(1+cos(t*0.14))"
            chain += f",scale={zw}:{zh},crop={width}:{height}:x='{xexpr}':y='{yexpr}'"
        label = f"sv{i}"
        parts.append(chain + f"[{label}]")
        labels.append(f"[{label}]")
    if not labels:
        return [], ""
    parts.append("".join(labels) + f"concat=n={len(labels)}:v=1:a=0[vscene]")
    return parts, "[vscene]"


def build_semantic_audio_filters(instances, original_volume):
    parts, labels = [], []
    for i, inst in enumerate(instances):
        ss, se = inst["sourceStart"], inst["sourceEnd"]
        factor = max(0.08, float(inst.get("factor") or 1))
        rate = 1.0 / factor
        chain = (
            f"[0:a]atrim=start={ss:.4f}:end={se:.4f},asetpts=PTS-STARTPTS,"
            f"volume={original_volume},{_atempo_chain(rate)}"
        )
        label = f"sa{i}"
        parts.append(chain + f"[{label}]")
        labels.append(f"[{label}]")
    if not labels:
        return [], ""
    parts.append("".join(labels) + f"concat=n={len(labels)}:v=0:a=1[aorig]")
    return parts, "[aorig]"


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
            voice_timeline = options.get("voice_timeline") or []
            voice_mode = str(options.get("voice_mode") or "none")
            voice_id = str(options.get("voice_id") or "").strip()
            voice_speed = float(options.get("voice_speed") or 1.0)
            voice_style = str(options.get("voice_style") or "football")
            voice_sync = str(options.get("voice_sync") or "fit")
            meaning_first = bool(options.get("meaning_first", False))
            meaning_audit = options.get("meaning_audit") or {}
            visual_sync = str(options.get("visual_sync") or "auto")
            visual_sync_max_hold = max(0.0, min(3.0, float(options.get("visual_sync_max_hold") or 3.0)))
            scene_plan_raw = options.get("scene_plan") or []
            voice_volume = max(0.25, min(2.0, float(options.get("voice_volume") or 1.0)))
            original_volume = max(0.0, min(1.0, float(options.get("original_volume") or 0.25)))
            burn_subtitles = bool(options.get("burn_subtitles", True))

            if meaning_first:
                audit_pass = bool(meaning_audit.get("pass"))
                audit_coverage = int(meaning_audit.get("coverage") or 0)
                audit_units = int(meaning_audit.get("totalUnits") or 0)
                if not audit_pass or audit_coverage != 100:
                    raise RuntimeError(
                        f"MEANING_FIRST_REQUIRED: pass={audit_pass} coverage={audit_coverage} units={audit_units}"
                    )
                if voice_sync != "clip_locked":
                    raise RuntimeError("MEANING_FIRST_REQUIRES_CLIP_LOCKED")

            narration_path = None
            voice_meta = {"complete": False, "coverage": 0, "segments": 0, "duration": 0.0, "timeline": []}
            uploaded_voice = options.get("uploaded_voice")
            if uploaded_voice and Path(uploaded_voice).exists():
                narration_path = Path(uploaded_voice)
                voice_meta = {
                    "complete": True, "coverage": 100, "segments": 1,
                    "duration": round(audio_duration_seconds(narration_path), 3), "timeline": [],
                    "source": "recorded",
                }
            elif voice_mode in ("ai_male", "ai_female", "clone") and narration:
                with render_jobs_lock:
                    render_jobs[job_id].update({
                        "stage": "VOICE V1.2 · 句级生成 0%",
                        "progress": 18, "updated_at": iso(),
                    })
                    _persist_render_jobs_locked()
                narration_path, voice_meta = synthesize_voice_timeline(
                    narration, voice_mode, voice_id, work,
                    voice_speed, voice_style, duration, voice_timeline, voice_sync,
                )
                with render_jobs_lock:
                    render_jobs[job_id].update({
                        "stage": f"解说完整性校验通过 · {voice_meta['segments']}句 · 100%",
                        "progress": 29, "updated_at": iso(),
                        "voiceComplete": True, "voiceCoverage": 100,
                        "voiceSegments": voice_meta["segments"],
                        "voiceDuration": voice_meta["duration"],
                        "voiceTimeline": voice_meta["timeline"][:120],
                    })
                    _persist_render_jobs_locked()

            narration_duration = audio_duration_seconds(narration_path) if narration_path else 0.0
            # V1.5 VIDEO FIRST: picture duration is the hard master clock.
            # Never extend an 82s clip to fit a longer narration.
            output_duration = duration
            if narration_duration > duration + 0.30:
                raise RuntimeError(
                    f"VOICE_EXCEEDS_VIDEO: narration {narration_duration:.2f}s > video {duration:.2f}s; "
                    "client must compress narration before render"
                )
            visual_gap = 0.0
            visual_factor = 1.0
            scene_plan = normalize_scene_plan(scene_plan_raw, duration, output_duration)
            visual_strategy = "semantic" if (visual_sync == "auto" and scene_plan) else "native"

            width, height = render_dimensions(aspect, quality)
            render_captions = captions
            semantic_instances = []
            if visual_strategy == "semantic":
                render_captions = remap_captions_to_scene_plan(captions, scene_plan)
                semantic_instances = expand_scene_instances(scene_plan)
                if not semantic_instances:
                    raise RuntimeError("SCENE_SYNC_PLAN_EMPTY")
            elif visual_strategy in ("stretch", "dynamic") and captions:
                render_captions = []
                for cap in captions:
                    cc = dict(cap)
                    try:
                        cc["start"] = float(cap.get("start") or 0) * visual_factor
                        cc["end"] = float(cap.get("end") or 0) * visual_factor
                    except Exception:
                        pass
                    render_captions.append(cc)

            subtitle_filter = ""
            if burn_subtitles and render_captions:
                ensure_cjk_font()
                ass_path = work / "captions.ass"
                write_ass(render_captions, ass_path, width, height)
                ass_escaped = str(ass_path).replace("\\", "/").replace(":", r"\:").replace("'", r"\'")
                font_escaped = str(FONT_DIR).replace("\\", "/").replace(":", r"\:").replace("'", r"\'")
                subtitle_filter = f"subtitles='{ass_escaped}':fontsdir='{font_escaped}'"

            exe = imageio_ffmpeg.get_ffmpeg_exe()
            out = work / "SAGI_CLOUD_RENDER.mp4"
            cmd = [exe, "-hide_banner", "-y", "-ss", str(start), "-t", str(duration), "-i", str(source)]
            if narration_path:
                cmd += ["-i", str(narration_path)]

            filters = []
            has_audio = media_has_audio(source)
            audio_map = None

            if visual_strategy == "semantic":
                vparts, vlabel = build_semantic_video_filters(semantic_instances, width, height)
                filters += vparts
                filters.append(f"{vlabel}{subtitle_filter if subtitle_filter else 'null'}[vout]")
                original_audio_label = ""
                if has_audio and original_volume > 0:
                    aparts, original_audio_label = build_semantic_audio_filters(semantic_instances, original_volume)
                    filters += aparts
                if narration_path and original_audio_label:
                    filters += [
                        f"[1:a]volume={voice_volume}[a1]",
                        f"{original_audio_label}[a1]amix=inputs=2:duration=longest:dropout_transition=1[aout]",
                    ]
                    audio_map = "[aout]"
                elif narration_path:
                    filters += [f"[1:a]volume={voice_volume}[aout]"]
                    audio_map = "[aout]"
                elif original_audio_label:
                    audio_map = original_audio_label
            else:
                vf = f"scale={width}:{height}:force_original_aspect_ratio=increase,crop={width}:{height},setsar=1"
                if visual_strategy in ("stretch", "dynamic"):
                    vf += f",setpts={visual_factor:.8f}*PTS"
                    if visual_strategy == "dynamic" and visual_factor > 1.08:
                        zw = max(width + 2, int(round(width * 1.06 / 2.0) * 2))
                        zh = max(height + 2, int(round(height * 1.06 / 2.0) * 2))
                        vf += (
                            f",scale={zw}:{zh},"
                            f"crop={width}:{height}:"
                            "x='(iw-ow)/2*(1+sin(t*0.19))':"
                            "y='(ih-oh)/2*(1+cos(t*0.13))'"
                        )
                elif visual_strategy == "short_hold":
                    vf += f",tpad=stop_mode=clone:stop_duration={min(visual_gap, visual_sync_max_hold):.3f}"
                if subtitle_filter:
                    vf += "," + subtitle_filter
                filters = [f"[0:v]{vf}[vout]"]
                if narration_path and has_audio and original_volume > 0:
                    original_af = f"volume={original_volume}"
                    if visual_strategy in ("stretch", "dynamic") and visual_factor > 1.001:
                        original_af += "," + _atempo_chain(1.0 / visual_factor)
                    filters += [
                        f"[0:a]{original_af}[a0]",
                        f"[1:a]volume={voice_volume}[a1]",
                        "[a0][a1]amix=inputs=2:duration=longest:dropout_transition=1[aout]",
                    ]
                    audio_map = "[aout]"
                elif narration_path:
                    filters += [f"[1:a]volume={voice_volume}[aout]"]
                    audio_map = "[aout]"
                elif has_audio and original_volume > 0:
                    if visual_strategy in ("stretch", "dynamic") and visual_factor > 1.001:
                        filters += [f"[0:a]volume={original_volume},{_atempo_chain(1.0 / visual_factor)}[aout]"]
                        audio_map = "[aout]"
                    elif original_volume != 1:
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
            cmd += ["-movflags", "+faststart", "-t", str(output_duration), "-progress", "pipe:1", "-nostats", str(out)]

            with render_jobs_lock:
                render_jobs[job_id].update({
                    "stage": "AI SCENE SYNC V1.4 · 内容匹配渲染" if visual_strategy == "semantic" else ("VISUAL SYNC · 动态画面匹配" if visual_strategy in ("stretch", "dynamic") else "云端编码成片"),
                    "progress": 34, "updated_at": iso(),
                    "visualSyncStrategy": visual_strategy,
                    "visualStretchFactor": round(visual_factor, 4),
                    "visualGap": round(visual_gap, 3),
                    "visualHoldSeconds": round(min(visual_gap, visual_sync_max_hold) if visual_strategy == "short_hold" else 0.0, 3),
                    "meaningFirst": meaning_first,
                    "meaningCoverage": int(meaning_audit.get("coverage") or 0) if meaning_first else 0,
                    "sceneSyncSegments": len(scene_plan) if visual_strategy == "semantic" else 0,
                    "sceneSyncInstances": len(semantic_instances) if visual_strategy == "semantic" else 0,
                })
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
                        pct = 34 + int(min(60, max(0, sec / max(0.2, output_duration) * 60)))
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
                    "voiceComplete": bool(voice_meta.get("complete")) if narration_path else True,
                    "voiceCoverage": int(voice_meta.get("coverage") or 0) if narration_path else 100,
                    "voiceSegments": int(voice_meta.get("segments") or 0),
                    "voiceDuration": round(float(voice_meta.get("duration") or narration_duration or 0), 3),
                    "voiceTimeline": (voice_meta.get("timeline") or [])[:120],
                    "visualSyncStrategy": visual_strategy,
                    "visualStretchFactor": round(visual_factor, 4),
                    "visualGap": round(visual_gap, 3),
                    "visualHoldSeconds": round(min(visual_gap, visual_sync_max_hold) if visual_strategy == "short_hold" else 0.0, 3),
                    "sceneSyncSegments": len(scene_plan) if visual_strategy == "semantic" else 0,
                    "sceneSyncInstances": len(semantic_instances) if visual_strategy == "semantic" else 0,
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


FOOTBALL_TEAM_ALIASES = {
    "皇马": "realmadrid", "皇家马德里": "realmadrid",
    "real madrid": "realmadrid", "real madrid cf": "realmadrid", "rma": "realmadrid",
    "巴萨": "barcelona", "巴塞罗那": "barcelona",
    "barcelona": "barcelona", "fc barcelona": "barcelona",
    "拜仁": "bayernmunich", "bayern munich": "bayernmunich", "bayern münchen": "bayernmunich",
    "曼城": "manchestercity", "manchester city": "manchestercity",
    "曼联": "manchesterunited", "manchester united": "manchesterunited",
    "利物浦": "liverpool", "liverpool": "liverpool",
    "阿森纳": "arsenal", "arsenal": "arsenal",
    "切尔西": "chelsea", "chelsea": "chelsea",
    "巴黎": "parissaintgermain", "巴黎圣日耳曼": "parissaintgermain",
    "psg": "parissaintgermain", "paris saint germain": "parissaintgermain",
    "国米": "intermilan", "国际米兰": "intermilan",
    "inter": "intermilan", "inter milan": "intermilan", "internazionale": "intermilan",
    "ac米兰": "acmilan", "ac milan": "acmilan",
    "尤文": "juventus", "juventus": "juventus",
    "马竞": "atleticomadrid", "atletico madrid": "atleticomadrid", "atlético madrid": "atleticomadrid",
    "多特": "borussiadortmund", "borussia dortmund": "borussiadortmund",
}

def _football_norm(value):
    text = str(value or "").strip().lower()
    text = (text.replace("á", "a").replace("é", "e").replace("í", "i")
                .replace("ó", "o").replace("ú", "u").replace("ü", "u").replace("ñ", "n"))
    text = re.sub(r"[^a-z0-9]+", "", text)
    for token in ("footballclub", "futbolclub", "clubdefutbol"):
        text = text.replace(token, "")
    # Strip common club suffixes only at the edges; never remove arbitrary
    # occurrences inside a team name.
    text = re.sub(r"^(?:afc|fc|cf)", "", text)
    text = re.sub(r"(?:afc|fc|cf)$", "", text)
    return text

def _football_canonical_team(value):
    raw = str(value or "").strip()
    if not raw:
        return ""
    direct = FOOTBALL_TEAM_ALIASES.get(raw.lower())
    if direct:
        return direct
    n = _football_norm(raw)
    if not n:
        return ""
    for alias, canonical in FOOTBALL_TEAM_ALIASES.items():
        if _football_norm(alias) == n:
            return canonical
    return n

def _football_team_match(query, *values):
    q = _football_canonical_team(query)
    if not q:
        return False
    for value in values:
        if _football_canonical_team(value) == q:
            return True
    return False

def _football_team_in_text(query, text):
    q = _football_canonical_team(query)
    body = _football_norm(text)
    if not q or not body:
        return False
    if q in body:
        return True
    raw = str(query or "").strip().lower()
    aliases = [k for k,v in FOOTBALL_TEAM_ALIASES.items() if v == q]
    return any(_football_norm(a) and _football_norm(a) in body for a in aliases + [raw])

def _football_cache_get(key):
    with football_cache_lock:
        row = football_cache.get(key)
        if not row:
            return None
        if time.time() - float(row.get("at") or 0) > FOOTBALL_CACHE_SECONDS:
            football_cache.pop(key, None)
            return None
        return row.get("data")

def _football_cache_set(key, data):
    with football_cache_lock:
        football_cache[key] = {"at": time.time(), "data": data}
    return data

def _football_match_row(provider, competition, date_value, home, away, hs, aas, status="FINISHED", source_url="", home_logo="", away_logo=""):
    try:
        home_score = int(hs)
        away_score = int(aas)
    except Exception:
        return None
    return {
        "provider": provider,
        "competition": competition,
        "competitionName": FOOTBALL_COMPETITIONS.get(competition, {}).get("name", competition),
        "date": str(date_value or ""),
        "home": str(home or "").strip(),
        "away": str(away or "").strip(),
        "homeScore": home_score,
        "awayScore": away_score,
        "score": f"{home_score}-{away_score}",
        "status": str(status or "FINISHED"),
        "sourceUrl": source_url,
        "homeLogo": str(home_logo or "").strip(),
        "awayLogo": str(away_logo or "").strip(),
    }

def _football_data_matches(team, competition, season):
    if not FOOTBALL_DATA_TOKEN:
        return []
    cfg = FOOTBALL_COMPETITIONS[competition]
    if not cfg.get("football_data"):
        return []
    url = f"https://api.football-data.org/v4/competitions/{cfg['football_data']}/matches"
    r = requests.get(url, params={"season": season, "status": "FINISHED"}, headers={"X-Auth-Token": FOOTBALL_DATA_TOKEN, "User-Agent": "SAGI-MATCH-DATA/3.7"}, timeout=(5, 18))
    r.raise_for_status()
    rows = []
    for m in (r.json() or {}).get("matches") or []:
        home = m.get("homeTeam") or {}
        away = m.get("awayTeam") or {}
        if not _football_team_match(team, home.get("name"), home.get("shortName"), home.get("tla"), away.get("name"), away.get("shortName"), away.get("tla")):
            continue
        score = ((m.get("score") or {}).get("fullTime") or {})
        row = _football_match_row("football-data.org", competition, m.get("utcDate"), home.get("name"), away.get("name"), score.get("home"), score.get("away"), m.get("status"), url, home.get("crest"), away.get("crest"))
        if row:
            rows.append(row)
    return rows

def _espn_matches(team, competition):
    cfg = FOOTBALL_COMPETITIONS[competition]
    end = now().date()
    start = end - timedelta(days=120)
    dates = start.strftime("%Y%m%d") + "-" + end.strftime("%Y%m%d")
    url = f"https://site.api.espn.com/apis/site/v2/sports/soccer/{cfg['espn']}/scoreboard"
    r = requests.get(url, params={"dates": dates, "limit": 1000}, headers={"User-Agent": "SAGI-MATCH-DATA/3.7"}, timeout=(5, 18))
    r.raise_for_status()
    rows = []
    for event in (r.json() or {}).get("events") or []:
        comps = event.get("competitions") or []
        if not comps:
            continue
        competitors = comps[0].get("competitors") or []
        home = next((x for x in competitors if x.get("homeAway") == "home"), None)
        away = next((x for x in competitors if x.get("homeAway") == "away"), None)
        if not home or not away:
            continue
        home_team = home.get("team") or {}
        away_team = away.get("team") or {}
        hn = (home_team.get("displayName") or home_team.get("shortDisplayName") or "")
        an = (away_team.get("displayName") or away_team.get("shortDisplayName") or "")
        home_logos = home_team.get("logos") or []
        away_logos = away_team.get("logos") or []
        home_logo = home_team.get("logo") or ((home_logos[0] or {}).get("href") if home_logos else "")
        away_logo = away_team.get("logo") or ((away_logos[0] or {}).get("href") if away_logos else "")
        if not _football_team_match(team, hn, an):
            continue
        state = (((event.get("status") or {}).get("type") or {}).get("state") or "")
        if state not in ("post",):
            continue
        row = _football_match_row("ESPN public feed", competition, event.get("date"), hn, an, home.get("score"), away.get("score"), "FINISHED", url, home_logo, away_logo)
        if row:
            rows.append(row)
    return rows


def _football_provider_team_query(team):
    raw = str(team or "").strip()
    aliases = {
        "皇马": "Real Madrid", "皇家马德里": "Real Madrid",
        "巴萨": "Barcelona", "巴塞罗那": "Barcelona",
        "曼城": "Manchester City", "曼联": "Manchester United",
        "利物浦": "Liverpool", "阿森纳": "Arsenal", "切尔西": "Chelsea",
        "拜仁": "Bayern Munich", "多特": "Borussia Dortmund",
        "巴黎": "Paris Saint Germain", "巴黎圣日耳曼": "Paris Saint Germain",
        "国际米兰": "Inter", "国米": "Inter", "AC米兰": "AC Milan",
        "尤文": "Juventus", "马竞": "Atletico Madrid",
    }
    return aliases.get(raw, raw)

def _api_football_matches(team, competition, season):
    if not API_FOOTBALL_KEY:
        return []
    headers = {"x-apisports-key": API_FOOTBALL_KEY, "User-Agent": "SAGI-MATCH-DATA/3.7"}
    provider_team = _football_provider_team_query(team)
    team_resp = requests.get("https://v3.football.api-sports.io/teams", params={"search": provider_team}, headers=headers, timeout=(5, 18))
    team_resp.raise_for_status()
    team_rows = (team_resp.json() or {}).get("response") or []
    if not team_rows:
        return []
    team_id = ((team_rows[0] or {}).get("team") or {}).get("id")
    if not team_id:
        return []
    cfg = FOOTBALL_COMPETITIONS[competition]
    league_resp = requests.get("https://v3.football.api-sports.io/leagues", params={"name": cfg["api_football"], "season": season}, headers=headers, timeout=(5, 18))
    league_resp.raise_for_status()
    leagues = (league_resp.json() or {}).get("response") or []
    if not leagues:
        return []
    league_id = ((leagues[0] or {}).get("league") or {}).get("id")
    if not league_id:
        return []
    fixture_resp = requests.get("https://v3.football.api-sports.io/fixtures", params={"team": team_id, "league": league_id, "season": season, "status": "FT"}, headers=headers, timeout=(5, 18))
    fixture_resp.raise_for_status()
    rows = []
    for item in (fixture_resp.json() or {}).get("response") or []:
        teams = item.get("teams") or {}
        goals = item.get("goals") or {}
        fixture = item.get("fixture") or {}
        row = _football_match_row("API-Football", competition, fixture.get("date"), (teams.get("home") or {}).get("name"), (teams.get("away") or {}).get("name"), goals.get("home"), goals.get("away"), "FINISHED", "https://www.api-football.com/", (teams.get("home") or {}).get("logo"), (teams.get("away") or {}).get("logo"))
        if row:
            rows.append(row)
    return rows

def _official_football_evidence(team, competition):
    cfg = FOOTBALL_COMPETITIONS[competition]
    url = cfg["official"]
    try:
        r = requests.get("https://r.jina.ai/" + url, headers={"Accept": "text/plain", "User-Agent": "SAGI-MATCH-DATA/3.7"}, timeout=(5, 18))
        if not r.ok:
            return {"checked": False, "url": url, "hits": []}
        text = (r.text or "")[:120000]
        lines = []
        for line in text.splitlines():
            if not _football_team_in_text(team, line):
                continue
            if re.search(r"\b\d{1,2}\s*[-–—:]\s*\d{1,2}\b", line):
                lines.append(re.sub(r"\s+", " ", line).strip()[:260])
            if len(lines) >= 12:
                break
        return {"checked": True, "url": url, "hits": lines}
    except Exception:
        return {"checked": False, "url": url, "hits": []}

def _official_confirms_match(official, row):
    evidence = (official or {}).get(row.get("competition")) or {}
    hits = evidence.get("hits") or []
    if not hits:
        return False
    home = _football_canonical_team(row.get("home"))
    away = _football_canonical_team(row.get("away"))
    score = str(row.get("score") or "")
    if not home or not away or not score:
        return False
    for hit in hits:
        body = _football_norm(hit)
        if home not in body or away not in body:
            continue
        nums = re.findall(r"\b(\d{1,2})\s*[-–—:]\s*(\d{1,2})\b", str(hit or ""))
        if any(f"{a}-{b}" == score for a,b in nums):
            return True
    return False

def _football_merge(rows, limit, official=None):
    buckets = {}
    for row in rows:
        date_key = str(row.get("date") or "")[:10]
        home_key = _football_canonical_team(row.get("home"))
        away_key = _football_canonical_team(row.get("away"))
        score_key = str(row.get("score") or "")
        key = "|".join([date_key, home_key, away_key, score_key])
        if not date_key or not home_key or not away_key or not score_key:
            continue
        b = buckets.setdefault(key, dict(row))
        providers = set(b.get("providers") or [b.get("provider")])
        providers.add(row.get("provider"))
        providers.discard(None)
        b["providers"] = sorted(providers)
        if not b.get("homeLogo") and row.get("homeLogo"):
            b["homeLogo"] = row.get("homeLogo")
        if not b.get("awayLogo") and row.get("awayLogo"):
            b["awayLogo"] = row.get("awayLogo")

    merged = []
    for b in buckets.values():
        providers = list(b.get("providers") or [])
        structured_count = len(set(providers))
        official_confirmed = _official_confirms_match(official or {}, b)
        verified = structured_count >= 2 or (structured_count >= 1 and official_confirmed)
        if structured_count >= 3:
            confidence = 99
            tier = "cross-source"
        elif structured_count >= 2:
            confidence = 96
            tier = "cross-source"
        elif official_confirmed:
            confidence = 93
            tier = "official-cross"
        else:
            confidence = 64 if providers == ["ESPN public feed"] else 72
            tier = "candidate"
        b["providerCount"] = structured_count
        b["officialConfirmed"] = bool(official_confirmed)
        b["verified"] = bool(verified)
        b["verificationTier"] = tier
        b["confidence"] = confidence
        merged.append(b)

    merged.sort(key=lambda x: str(x.get("date") or ""), reverse=True)
    verified_rows = [x for x in merged if x.get("verified")]
    candidate_rows = [x for x in merged if not x.get("verified")]
    cap = max(1, min(20, int(limit or 8)))
    return verified_rows[:cap], candidate_rows[:cap]

def football_form_payload(team, competition="AUTO", season=2026, limit=8):
    all_codes = list(FOOTBALL_COMPETITIONS.keys())
    requested = all_codes if competition == "AUTO" else [competition]
    cache_key = json.dumps(["v2", team, requested, season, limit], ensure_ascii=False)
    cached = _football_cache_get(cache_key)
    if cached is not None:
        return cached

    all_rows = []
    provider_errors = {}
    official = {}
    relevant = []
    provider_counts = {}

    def add_rows(provider, rows):
        clean = list(rows or [])
        if clean:
            provider_counts[provider] = provider_counts.get(provider, 0) + len(clean)
            all_rows.extend(clean)

    if competition == "AUTO":
        discovered = {}
        def espn_task(comp):
            try:
                return comp, _espn_matches(team, comp), ""
            except Exception as e:
                return comp, [], str(e)[:180]

        with ThreadPoolExecutor(max_workers=6) as pool:
            futures = [pool.submit(espn_task, comp) for comp in requested]
            for future in as_completed(futures):
                comp, rows, error = future.result()
                if error:
                    provider_errors[f"ESPN public feed:{comp}"] = error
                if rows:
                    discovered[comp] = rows
                    add_rows("ESPN public feed", rows)
        relevant = list(discovered.keys())
        if not relevant:
            relevant = [code for code, cfg in FOOTBALL_COMPETITIONS.items() if cfg.get("primary")]
    else:
        relevant = requested
        try:
            add_rows("ESPN public feed", _espn_matches(team, competition))
        except Exception as e:
            provider_errors[f"ESPN public feed:{competition}"] = str(e)[:180]

    for comp in relevant:
        official[comp] = _official_football_evidence(team, comp)
        for name, fn in (
            ("football-data.org", lambda c=comp: _football_data_matches(team, c, season)),
            ("API-Football", lambda c=comp: _api_football_matches(team, c, season)),
        ):
            try:
                add_rows(name, fn())
            except Exception as e:
                provider_errors[f"{name}:{comp}"] = str(e)[:180]

    matches, candidates = _football_merge(all_rows, limit, official)
    official_hits = sum(len((official.get(c) or {}).get("hits") or []) for c in relevant)
    checked = ["ESPN public feed"]
    if any((official.get(c) or {}).get("checked") for c in relevant):
        checked.insert(0, "official competition websites")
    if FOOTBALL_DATA_TOKEN:
        checked.append("football-data.org")
    if API_FOOTBALL_KEY:
        checked.append("API-Football")
    active = [name for name in ("football-data.org", "API-Football", "ESPN public feed") if provider_counts.get(name)]
    if official_hits:
        active.insert(0, "official competition websites")

    return _football_cache_set(cache_key, {
        "ok": True,
        "version": "2.0",
        "team": team,
        "canonicalTeam": _football_canonical_team(team),
        "competition": competition,
        "season": season,
        "matches": matches,
        "candidates": candidates,
        "relevantCompetitions": relevant,
        "official": official,
        "officialHits": official_hits,
        "providers": {
            "priority": ["official competition websites", "football-data.org", "API-Football", "ESPN public feed"],
            "active": active,
            "checked": checked,
            "counts": provider_counts,
            "footballDataConfigured": bool(FOOTBALL_DATA_TOKEN),
            "apiFootballConfigured": bool(API_FOOTBALL_KEY),
            "sportmonksConfigured": bool(SPORTMONKS_TOKEN),
        },
        "verificationPolicy": {
            "autoApply": "two independent structured sources OR one structured source confirmed by the official competition page",
            "singleSource": "candidate only; never auto-applied to poster",
            "verifiedCount": len(matches),
            "candidateCount": len(candidates),
        },
        "errors": provider_errors,
        "generatedAt": iso(),
    })

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
        "mediaKind": job.get("mediaKind", ""),
        "fileCount": int(job.get("fileCount", 0) or 0),
        "engineTrace": list(job.get("engineTrace") or []),
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

def _looks_like_no_video(message):
    text = (message or "").lower()
    return (
        "there is no video in this post" in text
        or "no video formats found" in text
        or "no video found" in text
    )

def _instagram_shortcode(url):
    try:
        path = (urlparse(url).path or "").strip("/")
        parts = path.split("/")
        if len(parts) >= 2 and parts[0] in ("p", "reel", "tv"):
            return re.sub(r"[^A-Za-z0-9_-]", "", parts[1])
    except Exception:
        pass
    return ""

def _decode_ig_media_url(raw):
    if not raw:
        return ""
    value = html_lib.unescape(str(raw))
    value = value.replace("\\u0026", "&").replace("\\u002F", "/").replace("\\/", "/")
    value = value.replace("\\u003D", "=").replace("\\u003F", "?")
    return value.strip()

def _extract_instagram_media_urls(text):
    """Extract only post media; avoid generic page/recommendation <img> assets."""
    if not text:
        return []

    def collect(patterns, limit=24):
        rows, seen = [], set()
        for kind, pattern in patterns:
            for match in re.finditer(pattern, text, flags=re.I):
                media_url = _decode_ig_media_url(match.group(1))
                low = media_url.lower()
                if not media_url.startswith("http"):
                    continue
                if not ("cdninstagram.com" in low or "fbcdn.net" in low):
                    continue
                if any(x in low for x in ("/profile", "s150x150", "s320x320")):
                    continue
                key = re.sub(r"[?&](?:_nc_ohc|ccb|oh|oe|stp|efg)=[^&]+", "", media_url)
                if key in seen:
                    continue
                seen.add(key)
                rows.append((kind, media_url))
                if len(rows) >= limit:
                    return rows
        return rows

    meta = collect([
        ("video", r'<meta[^>]+property=["\']og:video(?::secure_url)?["\'][^>]+content=["\']([^"\']+)'),
        ("video", r'<meta[^>]+content=["\']([^"\']+)["\'][^>]+property=["\']og:video(?::secure_url)?["\']'),
        ("video", r'<source[^>]+src=["\']([^"\']+)'),
        ("image", r'<meta[^>]+property=["\']og:image(?::secure_url)?["\'][^>]+content=["\']([^"\']+)'),
        ("image", r'<meta[^>]+content=["\']([^"\']+)["\'][^>]+property=["\']og:image(?::secure_url)?["\']'),
    ], limit=6)

    # A normal single post should return one media item. If video is present,
    # do not also download its poster image.
    carousel = any(marker in text for marker in (
        "edge_sidecar_to_children", '"carousel_media"', '"product_type":"carousel"',
        '"product_type": "carousel"', "GraphSidecar",
    ))
    if not carousel:
        videos = [row for row in meta if row[0] == "video"]
        if videos:
            return videos[:1]
        images = [row for row in meta if row[0] == "image"]
        return images[:1]

    # Carousel JSON contains one display_url/video_url per item. Generic img tags
    # are intentionally excluded so recommendations/login assets are never packed.
    structured = collect([
        ("video", r'"video_url"\s*:\s*"([^"]+)"'),
        ("image", r'"display_url"\s*:\s*"([^"]+)"'),
    ], limit=20)
    return structured or meta[:1]

def _requests_proxy_kwargs():
    if not INSTAGRAM_PROXY:
        return {}
    return {"proxies": {"http": INSTAGRAM_PROXY, "https": INSTAGRAM_PROXY}}

def _curl_proxy_kwargs():
    if not INSTAGRAM_PROXY:
        return {}
    return {"proxy": INSTAGRAM_PROXY}

def _save_remote_media(media, work, wanted_name, strategy):
    if not media:
        raise RuntimeError("INSTAGRAM_FAST_NO_MEDIA")
    base = safe_name(wanted_name or "SAGI_INSTAGRAM_POST")
    saved = []
    total = 0
    max_bytes = MAX_FILE_MB * 1024 * 1024
    headers = {
        "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 Version/18.5 Mobile/15E148 Safari/604.1",
        "Referer": "https://www.instagram.com/",
    }
    for idx, (kind, media_url) in enumerate(media, start=1):
        try:
            resp = requests.get(media_url, headers=headers, stream=True, timeout=(5, 20), **_requests_proxy_kwargs())
            resp.raise_for_status()
            ctype = (resp.headers.get("Content-Type") or "").lower()
            ext = ".mp4" if kind == "video" or "video/" in ctype else ".jpg"
            path = Path(work) / f"{idx:02d}{ext}"
            size = 0
            with path.open("wb") as out:
                for chunk in resp.iter_content(chunk_size=256 * 1024):
                    if not chunk:
                        continue
                    size += len(chunk)
                    total += len(chunk)
                    if total > max_bytes:
                        raise RuntimeError(f"帖子媒体总大小超过云端限制 {MAX_FILE_MB}MB")
                    out.write(chunk)
            if size > 1500:
                saved.append((kind, path))
            else:
                path.unlink(missing_ok=True)
        except Exception:
            continue

    if not saved:
        raise RuntimeError("INSTAGRAM_FAST_MEDIA_FETCH_FAILED")

    if len(saved) == 1:
        kind, src = saved[0]
        ext = src.suffix
        filename = base + ext
        dst = Path(work) / filename
        if src.resolve() != dst.resolve():
            src.replace(dst)
        media_path = dst
        media_kind = "video" if kind == "video" else "image"
        count = 1
    else:
        filename = base + "_CAROUSEL.zip"
        media_path = Path(work) / filename
        with zipfile.ZipFile(media_path, "w", compression=zipfile.ZIP_STORED) as zf:
            for idx, (_, src) in enumerate(saved, start=1):
                zf.write(src, arcname=f"{idx:02d}{src.suffix}")
        for _, src in saved:
            src.unlink(missing_ok=True)
        media_kind = "carousel"
        count = len(saved)

    return media_path, filename, media_kind, count

def run_instagram_fast_post(job_id, url, wanted_name):
    """Fast public-page fallback. It must finish quickly on cloud IPs."""
    with jobs_lock:
        job = jobs.get(job_id)
        if not job:
            return
        job.update({
            "status": "instagram_fast",
            "updated_at": iso(),
            "strategy": "instagram-html",
            "error": "",
            "errorCode": "",
        })

    shortcode = _instagram_shortcode(url)
    if not shortcode:
        raise RuntimeError("INSTAGRAM_FAST_BAD_URL")
    work = tempfile.mkdtemp(prefix=f"sagi_ig_fast_{job_id}_")
    try:
        pages = [
            f"https://www.instagram.com/p/{shortcode}/",
            f"https://www.instagram.com/p/{shortcode}/embed/",
        ]
        media = []
        headers = {
            "Accept-Language": "en-US,en;q=0.9",
            "Referer": "https://www.instagram.com/",
        }
        for page in pages:
            try:
                r = curl_requests.get(
                    page,
                    headers=headers,
                    impersonate="chrome",
                    timeout=8,
                    allow_redirects=True,
                    **_curl_proxy_kwargs(),
                )
                if int(getattr(r, "status_code", 0) or 0) >= 400:
                    continue
                media = _extract_instagram_media_urls(getattr(r, "text", "") or "")
                if media:
                    break
            except Exception:
                continue
        if not media:
            raise RuntimeError("INSTAGRAM_FAST_NO_MEDIA")

        with jobs_lock:
            current = jobs.get(job_id)
            if current:
                current.update({"status": "instagram_fetching", "updated_at": iso()})
        media_path, filename, kind, count = _save_remote_media(media, work, wanted_name, "instagram-html")
        with jobs_lock:
            job = jobs.get(job_id)
            if not job:
                shutil.rmtree(work, ignore_errors=True)
                return
            job.update({
                "status": "ready",
                "updated_at": iso(),
                "path": str(media_path),
                "workdir": work,
                "filename": filename,
                "title": filename,
                "size": media_path.stat().st_size,
                "strategy": "instagram-html",
                "mediaKind": kind,
                "fileCount": count,
                "error": "",
                "errorCode": "",
            })
    except Exception:
        shutil.rmtree(work, ignore_errors=True)
        raise

def run_gallery_download(job_id, url, wanted_name):
    """Instagram photo/carousel fallback. Streams media to disk and packages carousels as ZIP."""
    with jobs_lock:
        job = jobs.get(job_id)
        if not job:
            return
        job.update({
            "status": "gallery_processing",
            "updated_at": iso(),
            "strategy": "gallery-dl",
            "error": "",
            "errorCode": "",
        })

    work = tempfile.mkdtemp(prefix=f"sagi_gallery_{job_id}_")
    try:
        cmd = [
            sys.executable, "-m", "gallery_dl",
            "--no-input", "--quiet",
            "--directory", work,
            "--user-agent",
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 Version/18.5 Mobile/15E148 Safari/604.1",
        ]
        if INSTAGRAM_PROXY:
            cmd += ["--proxy", INSTAGRAM_PROXY]
        cmd += [url]
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=25)
        if proc.returncode != 0:
            detail = (proc.stderr or proc.stdout or "gallery-dl failed").strip()
            raise RuntimeError("INSTAGRAM_POST_FALLBACK_FAILED: " + detail[-900:])

        allowed = {".jpg", ".jpeg", ".png", ".webp", ".gif", ".mp4", ".mov", ".m4v", ".webm"}
        files = [
            p for p in Path(work).rglob("*")
            if p.is_file() and p.suffix.lower() in allowed and p.stat().st_size > 0
        ]
        if not files:
            raise RuntimeError("INSTAGRAM_POST_FALLBACK_EMPTY")

        total = sum(p.stat().st_size for p in files)
        if total > MAX_FILE_MB * 1024 * 1024:
            raise RuntimeError(f"帖子媒体总大小超过云端限制 {MAX_FILE_MB}MB")

        base = safe_name(wanted_name or "SAGI_INSTAGRAM_POST")
        video_exts = {".mp4", ".mov", ".m4v", ".webm"}
        if len(files) == 1:
            src = files[0]
            ext = src.suffix.lower() or ".bin"
            filename = base if base.lower().endswith(ext) else base + ext
            dst = Path(work) / filename
            if src.resolve() != dst.resolve():
                if dst.exists():
                    dst.unlink()
                shutil.move(str(src), str(dst))
            media_path = dst
            kind = "video" if ext in video_exts else "image"
            count = 1
        else:
            with jobs_lock:
                current = jobs.get(job_id)
                if current:
                    current.update({"status": "gallery_packaging", "updated_at": iso()})
            filename = base + "_CAROUSEL.zip"
            media_path = Path(work) / filename
            with zipfile.ZipFile(media_path, "w", compression=zipfile.ZIP_STORED) as zf:
                for idx, src in enumerate(sorted(files), start=1):
                    ext = src.suffix.lower() or ".bin"
                    zf.write(src, arcname=f"{idx:02d}{ext}")
            for src in files:
                try:
                    if src.resolve() != media_path.resolve():
                        src.unlink()
                except Exception:
                    pass
            kind = "carousel"
            count = len(files)

        size = media_path.stat().st_size
        with jobs_lock:
            job = jobs.get(job_id)
            if not job:
                shutil.rmtree(work, ignore_errors=True)
                return
            if job.get("workdir") and job.get("workdir") != work:
                shutil.rmtree(job["workdir"], ignore_errors=True)
            job.update({
                "status": "ready",
                "updated_at": iso(),
                "path": str(media_path),
                "workdir": work,
                "filename": filename,
                "title": filename,
                "size": size,
                "strategy": "gallery-dl",
                "mediaKind": kind,
                "fileCount": count,
                "error": "",
                "errorCode": "",
            })
    except Exception:
        shutil.rmtree(work, ignore_errors=True)
        raise

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
    platform = source_platform(url)
    with jobs_lock:
        job = jobs.get(job_id)
        if not job:
            return
        job["status"] = "router_trying"
        job["updated_at"] = iso()
        job["strategy"] = "router"
        job["engineTrace"] = []

    # V3.0: platform-aware engines first. Each engine is bounded and has a
    # small circuit breaker, so one broken upstream cannot stall the whole job.
    for engine in _router_engines(platform):
        if run_router_engine(job_id, engine, url, wanted_name):
            return

    work = tempfile.mkdtemp(prefix=f"sagi_cloud_{job_id}_")
    strategies = ["web", "ios", "android"] if is_instagram_url(url) else ["direct"]
    info = None
    errors = []
    saw_429 = False
    needs_gallery = False

    try:
        for strategy in strategies:
            with jobs_lock:
                job = jobs.get(job_id)
                if job:
                    trace = list(job.get("engineTrace") or [])
                    native_name = "yt-dlp-" + strategy
                    if not trace or trace[-1] != native_name:
                        trace.append(native_name)
                    job["engineTrace"] = trace[-8:]
                    job["status"] = "router_trying"
                    job["strategy"] = native_name
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
                if is_instagram_url(url) and _looks_like_no_video(msg):
                    needs_gallery = True
                    break
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
                if is_instagram_url(url) and _looks_like_no_video(msg):
                    needs_gallery = True
                    break
                time.sleep(1)

        if not info:
            # YouTube keeps yt-dlp first for quality/format reliability; btch is
            # only its fallback. Other platforms already tried btch above.
            if platform == "youtube" and _engine_can_try("btch"):
                shutil.rmtree(work, ignore_errors=True)
                if run_router_engine(job_id, "btch", url, wanted_name):
                    return
                work = tempfile.mkdtemp(prefix=f"sagi_cloud_{job_id}_")

            # Instagram always gets both dedicated post extractors after native
            # yt-dlp fails, regardless of whether the native error was 429,
            # no-video, or a changed extractor response.
            if is_instagram_url(url):
                shutil.rmtree(work, ignore_errors=True)
                try:
                    run_instagram_fast_post(job_id, url, wanted_name)
                    return
                except Exception as e:
                    errors.append("instagram-html: " + str(e)[:220])
                try:
                    run_gallery_download(job_id, url, wanted_name)
                    return
                except subprocess.TimeoutExpired:
                    errors.append("gallery-dl: timeout")
                except Exception as e:
                    errors.append("gallery-dl: " + str(e)[:220])
            if saw_429:
                raise RuntimeError(
                    "SAGI_DOWNLOAD_RATE_LIMIT: source platform temporarily rejected the cloud IP."
                )
            if needs_gallery:
                raise RuntimeError("INSTAGRAM_CLOUD_BLOCKED: Instagram 当前限制了云端访问，请稍后重试。")
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
                "strategy": "yt-dlp",
                "error": "",
                "errorCode": "",
            })
    except Exception as e:
        shutil.rmtree(work, ignore_errors=True)
        msg = str(e)
        if "SAGI_DOWNLOAD_RATE_LIMIT" in msg:
            code = "cloud_download_rate_limit"
        elif "INSTAGRAM_CLOUD_BLOCKED" in msg:
            code = "instagram_cloud_blocked"
        else:
            code = "cloud_download_failed"
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
        "matchIntelligence": MATCH_INTELLIGENCE_LITE,
        "matchIntelligenceVersion": "1.0-cloud-lite" if MATCH_INTELLIGENCE_LITE else "",
        "matchIntelligenceEngine": "YOLO11 ONNX Runtime" if MATCH_INTELLIGENCE_LITE else "",
        "matchIntelligenceError": MATCH_INTELLIGENCE_LITE_ERROR if not MATCH_INTELLIGENCE_LITE else "",
        "instagram": True,
        "cloudDownload": True,
        "cloudDownloadVersion": "3.0",
        "downloadPrimary": "multi-engine-router",
        "downloadRouter": True,
        "downloadRouterVersion": "3.0",
        "btchEnabled": bool(BTCH_BASE),
        "btchBaseMode": "configurable-public-fallback",
        "parthDlEnabled": True,
        "tikwmEnabled": True,
        "fxtwitterEnabled": True,
        "cobaltConfigured": bool(cobalt_base()),
        "cobaltMode": "legacy-fallback-only",
        "downloadPlatforms": ["Instagram", "YouTube", "TikTok", "X"],
        "downloadEngineOrder": {
            "Instagram": ["btch", "parth-dl", "yt-dlp", "instagram-html", "gallery-dl"],
            "TikTok": ["btch", "tikwm", "yt-dlp"],
            "X": ["fxtwitter", "btch", "yt-dlp"],
            "YouTube": ["yt-dlp", "btch"],
        },
        "instagramPostFallback": "btch -> parth-dl -> yt-dlp -> html-fast -> gallery-dl-short",
        "instagramProxyConfigured": bool(INSTAGRAM_PROXY),
        "instagramEgress": "proxy" if INSTAGRAM_PROXY else "render-direct",
        "instagramFastTimeoutSeconds": 16,
        "galleryFallbackTimeoutSeconds": 25,
        "downloadMediaKinds": ["video", "image", "carousel-zip"],
        "hybridWorker": True,
        "workerOnline": worker_online(),
        "activation": True,
        "marketIntake": market_cloud_ready(),
        "marketIntakeVersion": "1.1",
        "captionFast": True,
        "captionMedia": True,
        "contextTranslate": True,
        "smartTranslate": True,
        "aiVoice": True,
        "aiVoiceFallback": True,
        "voiceDirectorVersion": "2.4",
        "animationFirst": True,
        "voiceOneShot": True,
        "voiceCaptionFromFinalAudio": True,
        "voiceSceneLock": True,
        "voiceSceneLockExactScript": False,
        "voiceSceneLockClusterRebalance": True,
        "voiceSemanticLock": True,
        "voiceSemanticCompression": True,
        "voiceSemanticMeaningProtected": True,
        "voiceMeaningFirst": True,
        "voiceLockstep": True,
        "voiceLockstepExactDuration": True,
        "voiceLockstepOriginalVideoMaster": True,
        "voiceMeaningIntegrityRequired": 100,
        "voiceMeaningAuditRequiredForAIRender": True,
        "voiceVideoDurationLock": True,
        "voiceAutoCondenseToClip": True,
        "voiceRenderNeverExtendsVideo": True,
        "aiVisualSync": True,
        "aiVisualSyncMaxHoldSeconds": 3,
        "aiVisualSyncSentenceMap": True,
        "aiSceneSync": True,
        "aiSceneSyncVersion": "1.5",
        "aiSceneSyncLocalFrameAnalysis": True,
        "aiSceneSyncSemanticCaptionMatch": True,
        "voiceNarrationNoCut": False,
        "voiceNarrationMeaningProtected": True,
        "voiceSentenceTimeline": True,
        "voiceCompletenessGuard": True,
        "voicePreviewMaxChars": 50000,
        "voicePreviewChunked": True,
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
        "footballDataHub": True,
        "footballDataHubVersion": "2.0",
        "footballCompetitions": list(FOOTBALL_COMPETITIONS.keys()),
        "footballDataConfigured": bool(FOOTBALL_DATA_TOKEN),
        "apiFootballConfigured": bool(API_FOOTBALL_KEY),
        "sportmonksConfigured": bool(SPORTMONKS_TOKEN),
        "localAI": True,
        "localAIVersion": "1.2",
        "localVisual": True,
        "localVisualVersion": "1.2",
        "localAIConfigured": bool(OPENAI_API_KEY),
        "localAIModel": SAGI_LOCAL_AI_MODEL if OPENAI_API_KEY else "",
        "localAIRateLimitPerHour": SAGI_LOCAL_AI_RATE_LIMIT_PER_HOUR,
        "localVisualMaxMB": SAGI_LOCAL_VISUAL_MAX_MB,
        "localPoster": True,
        "localPosterVersion": "1.2.1",
        "localImageModel": SAGI_LOCAL_IMAGE_MODEL if OPENAI_API_KEY else "",
        "localImageQuality": SAGI_LOCAL_IMAGE_QUALITY,
        "configured": bool(SERVER_SECRET),
    })



def _local_ai_rate_allowed():
    forwarded = (request.headers.get("X-Forwarded-For") or "").split(",")[0].strip()
    key = forwarded or request.remote_addr or "unknown"
    cutoff = time.time() - 3600
    with local_ai_rate_lock:
        arr = [t for t in local_ai_hits.get(key, []) if t >= cutoff]
        if len(arr) >= SAGI_LOCAL_AI_RATE_LIMIT_PER_HOUR:
            local_ai_hits[key] = arr
            return False
        arr.append(time.time())
        local_ai_hits[key] = arr
    return True

def _responses_output_text(payload):
    chunks = []
    for item in (payload or {}).get("output") or []:
        if not isinstance(item, dict) or item.get("type") != "message":
            continue
        for part in item.get("content") or []:
            if isinstance(part, dict) and part.get("type") == "output_text":
                text = str(part.get("text") or "").strip()
                if text:
                    chunks.append(text)
    return "\n".join(chunks).strip()

SAGI_LOCAL_PACK_SCHEMA = {
    "type": "object",
    "properties": {
        "headline": {"type": "string"},
        "poster": {"type": "string"},
        "video": {"type": "string"},
        "douyin": {"type": "string"},
        "moments": {"type": "string"},
        "variants": {
            "type": "array",
            "minItems": 3,
            "maxItems": 3,
            "items": {
                "type": "object",
                "properties": {
                    "angle": {"type": "string"},
                    "headline": {"type": "string"},
                    "hook": {"type": "string"}
                },
                "required": ["angle", "headline", "hook"],
                "additionalProperties": False
            }
        },
        "score": {
            "type": "object",
            "properties": {
                "clarity": {"type": "integer", "minimum": 0, "maximum": 100},
                "conversion": {"type": "integer", "minimum": 0, "maximum": 100},
                "brand": {"type": "integer", "minimum": 0, "maximum": 100},
                "overall": {"type": "integer", "minimum": 0, "maximum": 100},
                "reason": {"type": "string"}
            },
            "required": ["clarity", "conversion", "brand", "overall", "reason"],
            "additionalProperties": False
        }
    },
    "required": ["headline", "poster", "video", "douyin", "moments", "variants", "score"],
    "additionalProperties": False
}

@app.post("/api/local-ai/generate")
def sagi_local_ai_generate():
    if not _local_ai_rate_allowed():
        return jsonify({"ok": False, "error": "AI hourly limit reached", "errorCode": "local_ai_rate_limit"}), 429
    if not OPENAI_API_KEY:
        return jsonify({
            "ok": False,
            "error": "AI provider is not configured",
            "errorCode": "local_ai_unconfigured",
            "fallback": True
        }), 503

    data = request.get_json(silent=True) or {}
    brief = str(data.get("brief") or "").strip()
    if not brief:
        return jsonify({"ok": False, "error": "brief is required"}), 400
    if len(brief) > 1200:
        return jsonify({"ok": False, "error": "brief is too long"}), 413

    profile = data.get("profile") if isinstance(data.get("profile"), dict) else {}
    safe_profile = {
        "name": str(profile.get("name") or "")[:120],
        "industry": str(profile.get("industry") or "")[:120],
        "product": str(profile.get("product") or "")[:300],
        "audience": str(profile.get("audience") or "")[:300],
        "brandTone": str(profile.get("brandTone") or "")[:300],
    }
    context = {
        "merchant": safe_profile,
        "brief": brief,
        "goal": str(data.get("goal") or "到店消费")[:80],
        "tone": str(data.get("tone") or "高级直接")[:80],
        "channel": "本地生活商家，中文内容，移动端",
    }

    system_prompt = """你是 SAGI AI LOCAL 的本地商业内容导演。
你的任务是把商家提供的真实信息，转换成可以直接发布的中文宣传内容。
原则：
1. 不编造价格、折扣、地址、销量、奖项、顾客评价、稀缺性或任何用户未提供的事实。
2. 不使用低俗、夸大、虚假承诺；标题要像真实本地商家，而不是AI套话。
3. 优先表达一个明确卖点、一个使用/到店场景、一个行动指令。
4. 海报方向必须可执行：说明3:4主视觉的主体、标题、利益点和CTA布局。
5. 15秒视频按时间段写，画面和字幕要能直接交给剪辑人员。
6. 抖音文案要短、自然、有本地生活感；朋友圈更像老板本人说话。
7. 给出3个明显不同的创意方向，不只是换同义词。
8. 质量评分要严格，低于80分也允许，reason用一句话解释最该优化什么。
只返回符合指定JSON结构的数据。"""

    body = {
        "model": SAGI_LOCAL_AI_MODEL,
        "input": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": json.dumps(context, ensure_ascii=False)}
        ],
        "text": {
            "format": {
                "type": "json_schema",
                "name": "sagi_local_marketing_pack",
                "strict": True,
                "schema": SAGI_LOCAL_PACK_SCHEMA
            }
        },
        "max_output_tokens": 2200,
        "store": False
    }

    started = time.time()
    try:
        r = requests.post(
            OPENAI_BASE_URL + "/v1/responses",
            headers={
                "Authorization": "Bearer " + OPENAI_API_KEY,
                "Content-Type": "application/json",
                "User-Agent": "SAGI-AI-LOCAL/1.2"
            },
            json=body,
            timeout=(6, SAGI_LOCAL_AI_TIMEOUT)
        )
        if r.status_code >= 400:
            detail = (r.text or "")[:500]
            return jsonify({
                "ok": False,
                "error": "AI provider request failed",
                "errorCode": "local_ai_provider_error",
                "status": r.status_code,
                "detail": detail,
                "fallback": True
            }), 502
        raw = r.json()
        text = _responses_output_text(raw)
        if not text:
            return jsonify({
                "ok": False,
                "error": "AI returned no usable content",
                "errorCode": "local_ai_empty",
                "fallback": True
            }), 502
        pack = json.loads(text)
        return jsonify({
            "ok": True,
            "engine": "openai-responses",
            "model": SAGI_LOCAL_AI_MODEL,
            "version": "1.2",
            "latencyMs": int((time.time() - started) * 1000),
            "pack": pack
        })
    except requests.Timeout:
        return jsonify({
            "ok": False,
            "error": "AI request timed out",
            "errorCode": "local_ai_timeout",
            "fallback": True
        }), 504
    except Exception as e:
        return jsonify({
            "ok": False,
            "error": "AI generation failed",
            "errorCode": "local_ai_failed",
            "detail": str(e)[:240],
            "fallback": True
        }), 502



SAGI_LOCAL_VISUAL_SCHEMA = {
    "type": "object",
    "properties": {
        "subject": {"type": "string"},
        "scene": {"type": "string"},
        "strengths": {
            "type": "array",
            "minItems": 2,
            "maxItems": 4,
            "items": {"type": "string"}
        },
        "fixes": {
            "type": "array",
            "minItems": 1,
            "maxItems": 4,
            "items": {"type": "string"}
        },
        "headline": {"type": "string"},
        "subheadline": {"type": "string"},
        "cta": {"type": "string"},
        "coverHeadline": {"type": "string"},
        "overlayPosition": {
            "type": "string",
            "enum": ["top", "bottom", "left", "right"]
        },
        "cropFocus": {
            "type": "string",
            "enum": ["center", "top", "bottom", "left", "right"]
        },
        "contrastOverlay": {
            "type": "string",
            "enum": ["dark_bottom", "dark_top", "dark_full", "none"]
        },
        "posterDirection": {"type": "string"},
        "coverDirection": {"type": "string"},
        "videoPlan": {"type": "string"},
        "publishCopy": {"type": "string"},
        "palette": {
            "type": "object",
            "properties": {
                "text": {"type": "string"},
                "accent": {"type": "string"},
                "shadow": {"type": "string"}
            },
            "required": ["text", "accent", "shadow"],
            "additionalProperties": False
        },
        "score": {
            "type": "object",
            "properties": {
                "imageQuality": {"type": "integer", "minimum": 0, "maximum": 100},
                "commercialPotential": {"type": "integer", "minimum": 0, "maximum": 100},
                "readability": {"type": "integer", "minimum": 0, "maximum": 100},
                "overall": {"type": "integer", "minimum": 0, "maximum": 100},
                "reason": {"type": "string"}
            },
            "required": ["imageQuality", "commercialPotential", "readability", "overall", "reason"],
            "additionalProperties": False
        }
    },
    "required": [
        "subject", "scene", "strengths", "fixes",
        "headline", "subheadline", "cta", "coverHeadline",
        "overlayPosition", "cropFocus", "contrastOverlay",
        "posterDirection", "coverDirection", "videoPlan", "publishCopy",
        "palette", "score"
    ],
    "additionalProperties": False
}

@app.post("/api/local-ai/visual")
def sagi_local_ai_visual():
    if not _local_ai_rate_allowed():
        return jsonify({"ok": False, "error": "AI hourly limit reached", "errorCode": "local_ai_rate_limit"}), 429
    if not OPENAI_API_KEY:
        return jsonify({
            "ok": False,
            "error": "AI provider is not configured",
            "errorCode": "local_ai_unconfigured",
            "fallback": True
        }), 503

    upload = request.files.get("image")
    if not upload:
        return jsonify({"ok": False, "error": "image is required"}), 400

    mime = str(upload.mimetype or "").lower().split(";")[0].strip()
    allowed = {"image/jpeg", "image/png", "image/webp", "image/gif"}
    if mime not in allowed:
        return jsonify({
            "ok": False,
            "error": "unsupported image type",
            "errorCode": "local_visual_unsupported_type",
            "supported": sorted(allowed)
        }), 415

    raw = upload.read(SAGI_LOCAL_VISUAL_MAX_MB * 1024 * 1024 + 1)
    if not raw:
        return jsonify({"ok": False, "error": "empty image"}), 400
    if len(raw) > SAGI_LOCAL_VISUAL_MAX_MB * 1024 * 1024:
        return jsonify({
            "ok": False,
            "error": f"image exceeds {SAGI_LOCAL_VISUAL_MAX_MB}MB",
            "errorCode": "local_visual_too_large"
        }), 413

    brief = str(request.form.get("brief") or "").strip()[:1200]
    profile_raw = str(request.form.get("profile") or "{}")
    try:
        profile = json.loads(profile_raw)
        if not isinstance(profile, dict):
            profile = {}
    except Exception:
        profile = {}

    safe_profile = {
        "name": str(profile.get("name") or "")[:120],
        "industry": str(profile.get("industry") or "")[:120],
        "product": str(profile.get("product") or "")[:300],
        "audience": str(profile.get("audience") or "")[:300],
        "brandTone": str(profile.get("brandTone") or "")[:300],
    }
    context = {
        "merchant": safe_profile,
        "brief": brief,
        "deliverables": ["3:4海报", "9:16短视频封面", "15秒视频视觉计划", "发布文案"],
        "language": "简体中文",
    }
    data_url = "data:" + mime + ";base64," + base64.b64encode(raw).decode("ascii")

    system_prompt = """你是 SAGI AI LOCAL 的商业视觉导演，服务本地小商家。
你要先看懂用户上传的真实照片，再给出可直接用于商业宣传的视觉方案。
严格遵守：
1. 只根据图片可见信息和商家明确提供的信息判断，不编造价格、折扣、地址、销量、奖项、评价、品牌历史或稀缺性。
2. 如果画面有人，只描述可见动作、服装、构图和场景；不要猜身份、姓名、年龄、种族、健康、宗教等敏感或不可见属性。
3. 不要把普通照片描述成“专业棚拍”“高端品牌合作”等图片无法证明的事实。
4. subject/scene 要简短准确；strengths 和 fixes 必须是能指导设计的视觉判断。
5. 3:4海报要尽量保留真实照片主体，避免遮挡主体；overlayPosition 和 cropFocus 必须可直接用于自动排版。
6. 标题尽量控制在18个汉字以内，副标题控制在26个汉字以内，CTA控制在10个汉字以内。
7. 9:16封面要适合手机端，前三秒能看懂卖点；不要堆满文字。
8. palette 返回适合叠加在原图上的十六进制颜色，例如 #FFFFFF；text、accent、shadow 必须是合法 #RRGGBB。
9. 评分要严格，特别是原图光线、主体清晰度、文字可读空间和商业转化潜力。
只返回符合指定JSON结构的数据。"""

    body = {
        "model": SAGI_LOCAL_AI_MODEL,
        "input": [
            {"role": "system", "content": system_prompt},
            {
                "role": "user",
                "content": [
                    {"type": "input_text", "text": json.dumps(context, ensure_ascii=False)},
                    {"type": "input_image", "image_url": data_url, "detail": "high"}
                ]
            }
        ],
        "text": {
            "format": {
                "type": "json_schema",
                "name": "sagi_local_visual_pack",
                "strict": True,
                "schema": SAGI_LOCAL_VISUAL_SCHEMA
            }
        },
        "max_output_tokens": 2600,
        "store": False
    }

    started = time.time()
    try:
        r = requests.post(
            OPENAI_BASE_URL + "/v1/responses",
            headers={
                "Authorization": "Bearer " + OPENAI_API_KEY,
                "Content-Type": "application/json",
                "User-Agent": "SAGI-AI-LOCAL/1.2"
            },
            json=body,
            timeout=(8, SAGI_LOCAL_AI_TIMEOUT)
        )
        if r.status_code >= 400:
            return jsonify({
                "ok": False,
                "error": "AI visual request failed",
                "errorCode": "local_visual_provider_error",
                "status": r.status_code,
                "detail": (r.text or "")[:500],
                "fallback": True
            }), 502
        raw_response = r.json()
        output_text = _responses_output_text(raw_response)
        if not output_text:
            return jsonify({
                "ok": False,
                "error": "AI returned no visual analysis",
                "errorCode": "local_visual_empty",
                "fallback": True
            }), 502
        pack = json.loads(output_text)
        return jsonify({
            "ok": True,
            "engine": "openai-responses-vision",
            "model": SAGI_LOCAL_AI_MODEL,
            "version": "1.2",
            "latencyMs": int((time.time() - started) * 1000),
            "pack": pack
        })
    except requests.Timeout:
        return jsonify({
            "ok": False,
            "error": "AI visual request timed out",
            "errorCode": "local_visual_timeout",
            "fallback": True
        }), 504
    except Exception as e:
        return jsonify({
            "ok": False,
            "error": "AI visual generation failed",
            "errorCode": "local_visual_failed",
            "detail": str(e)[:240],
            "fallback": True
        }), 502



@app.post("/api/local-ai/poster")
def sagi_local_ai_poster():
    if not _local_ai_rate_allowed():
        return jsonify({"ok": False, "error": "AI hourly limit reached", "errorCode": "local_ai_rate_limit"}), 429
    if not OPENAI_API_KEY:
        return jsonify({
            "ok": False,
            "error": "AI image provider is not configured",
            "errorCode": "local_ai_unconfigured",
            "fallback": True
        }), 503

    upload = request.files.get("image")
    if not upload:
        return jsonify({"ok": False, "error": "image is required"}), 400

    mime = str(upload.mimetype or "").lower().split(";")[0].strip()
    allowed = {"image/jpeg", "image/png", "image/webp"}
    if mime not in allowed:
        return jsonify({
            "ok": False,
            "error": "poster source must be jpg, png or webp",
            "errorCode": "local_poster_unsupported_type",
            "supported": sorted(allowed)
        }), 415

    raw = upload.read(SAGI_LOCAL_VISUAL_MAX_MB * 1024 * 1024 + 1)
    if not raw:
        return jsonify({"ok": False, "error": "empty image"}), 400
    if len(raw) > SAGI_LOCAL_VISUAL_MAX_MB * 1024 * 1024:
        return jsonify({
            "ok": False,
            "error": f"image exceeds {SAGI_LOCAL_VISUAL_MAX_MB}MB",
            "errorCode": "local_poster_too_large"
        }), 413

    brief = str(request.form.get("brief") or "").strip()[:1200]
    profile_raw = str(request.form.get("profile") or "{}")
    pack_raw = str(request.form.get("pack") or "{}")
    try:
        profile = json.loads(profile_raw)
        if not isinstance(profile, dict):
            profile = {}
    except Exception:
        profile = {}
    try:
        visual_pack = json.loads(pack_raw)
        if not isinstance(visual_pack, dict):
            visual_pack = {}
    except Exception:
        visual_pack = {}

    merchant = str(profile.get("name") or "本地商家")[:120]
    industry = str(profile.get("industry") or "本地生活")[:120]
    product = str(profile.get("product") or "")[:300]
    brand_tone = str(profile.get("brandTone") or "高级、真实、克制")[:300]
    subject = str(visual_pack.get("subject") or "")[:300]
    scene = str(visual_pack.get("scene") or "")[:300]

    prompt = f"""把这张真实商家照片编辑成一张高级、可信、可直接用于本地商业宣传的广告主视觉底图。
商家：{merchant}
行业：{industry}
主打产品/服务：{product}
宣传目标：{brief}
品牌调性：{brand_tone}
已识别主体：{subject}
场景：{scene}

必须遵守：
- 保留原图核心商品、人物、门店或服务主体的真实外观，不改变品牌标识、产品结构、人物身份特征。
- 可以改善光线、背景层次、景深、色彩、桌面/环境杂乱，让画面更像真实品牌广告摄影。
- 不要凭空增加不存在的商品、菜品、价格、折扣、奖项、评价、Logo、二维码或品牌名称。
- 不要在图片中生成任何文字、数字、价格、Logo或水印；文字由SAGI程序后续精确叠加。
- 构图为“通用商业主视觉”：主体尽量居中或略偏中心，四周尤其顶部和底部保留足够干净空间，方便同时裁成3:4海报和9:16短视频封面。
- 画面要高级、真实、克制，不要廉价促销贴纸，不要过度HDR，不要虚假的奢华场景。
- 优先像真实商业摄影/品牌广告，而不是AI插画。
"""
    data_url = "data:" + mime + ";base64," + base64.b64encode(raw).decode("ascii")
    body = {
        "images": [{"image_url": data_url}],
        "prompt": prompt,
        "model": SAGI_LOCAL_IMAGE_MODEL,
        "quality": SAGI_LOCAL_IMAGE_QUALITY,
        "size": "1024x1536",
        "output_format": "jpeg",
        "output_compression": 86,
        "background": "opaque",
        "complexity": "medium",
        "n": 1
    }

    started = time.time()
    try:
        r = requests.post(
            OPENAI_BASE_URL + "/v1/images/edits",
            headers={
                "Authorization": "Bearer " + OPENAI_API_KEY,
                "Content-Type": "application/json",
                "User-Agent": "SAGI-AI-LOCAL-POSTER/1.2.1"
            },
            json=body,
            timeout=(10, max(60, SAGI_LOCAL_AI_TIMEOUT * 2))
        )
        if r.status_code >= 400:
            return jsonify({
                "ok": False,
                "error": "AI poster request failed",
                "errorCode": "local_poster_provider_error",
                "status": r.status_code,
                "detail": (r.text or "")[:600],
                "fallback": True
            }), 502
        payload = r.json()
        items = payload.get("data") or []
        b64 = str(items[0].get("b64_json") or "") if items and isinstance(items[0], dict) else ""
        if not b64:
            return jsonify({
                "ok": False,
                "error": "AI poster returned no image",
                "errorCode": "local_poster_empty",
                "fallback": True
            }), 502
        return jsonify({
            "ok": True,
            "version": "1.2.1",
            "engine": "openai-image-edit",
            "model": SAGI_LOCAL_IMAGE_MODEL,
            "quality": SAGI_LOCAL_IMAGE_QUALITY,
            "mime": "image/jpeg",
            "imageBase64": b64,
            "latencyMs": int((time.time() - started) * 1000)
        })
    except requests.Timeout:
        return jsonify({
            "ok": False,
            "error": "AI poster request timed out",
            "errorCode": "local_poster_timeout",
            "fallback": True
        }), 504
    except Exception as e:
        return jsonify({
            "ok": False,
            "error": "AI poster generation failed",
            "errorCode": "local_poster_failed",
            "detail": str(e)[:240],
            "fallback": True
        }), 502


FOOTBALL_CREST_HOST_SUFFIXES = ("espncdn.com", "football-data.org", "api-sports.io")

@app.get("/api/football/crest")
def football_crest():
    if not authorized():
        return jsonify({"ok": False, "error": "Unauthorized"}), 401
    raw = (request.args.get("url") or "").strip()
    try:
        parsed = urlparse(raw)
    except Exception:
        parsed = None
    host = (parsed.hostname or "").lower() if parsed else ""
    if not parsed or parsed.scheme != "https" or not host or not any(host == suffix or host.endswith("." + suffix) for suffix in FOOTBALL_CREST_HOST_SUFFIXES):
        return jsonify({"ok": False, "error": "crest host not allowed"}), 400
    try:
        r = requests.get(raw, headers={"User-Agent": "SAGI-MATCH-DATA/3.9"}, timeout=(4, 12))
        r.raise_for_status()
        body = r.content or b""
        ctype = (r.headers.get("Content-Type") or "").split(";")[0].strip().lower()
        if not ctype.startswith("image/") or not body or len(body) > 2 * 1024 * 1024:
            return jsonify({"ok": False, "error": "invalid crest response"}), 502
        return Response(body, mimetype=ctype)
    except Exception as e:
        return jsonify({"ok": False, "error": "crest fetch failed", "detail": str(e)[:120]}), 502

@app.get("/api/football/status")
def football_status():
    if not authorized():
        return jsonify({"ok": False, "error": "Unauthorized"}), 401
    return jsonify({
        "ok": True,
        "version": "2.0",
        "competitions": [{"code": code, "name": cfg["name"], "official": cfg["official"]} for code, cfg in FOOTBALL_COMPETITIONS.items() if cfg.get("primary")],
        "providers": {
            "priority": ["official competition websites", "football-data.org", "API-Football", "ESPN public feed"],
            "policy": "verified matches require two-source agreement; single-source rows are candidates only",
            "footballDataConfigured": bool(FOOTBALL_DATA_TOKEN),
            "apiFootballConfigured": bool(API_FOOTBALL_KEY),
            "sportmonksConfigured": bool(SPORTMONKS_TOKEN),
            "espnPublicFeed": True,
        },
    })

@app.post("/api/football/form")
def football_form():
    if not authorized():
        return jsonify({"ok": False, "error": "Unauthorized"}), 401
    data = request.get_json(silent=True) or {}
    team = str(data.get("team") or "").strip()
    competition = str(data.get("competition") or "AUTO").strip().upper()
    season = int(data.get("season") or 2026)
    limit = int(data.get("limit") or 8)
    if len(team) < 2:
        return jsonify({"ok": False, "error": "team required"}), 400
    if competition != "AUTO" and competition not in FOOTBALL_COMPETITIONS:
        return jsonify({"ok": False, "error": "unsupported competition"}), 400
    try:
        return jsonify(football_form_payload(team, competition, season, limit))
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)[:500]}), 502

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
        {"voice_id": "edge-zh-yunjian", "name": "云健 · 体育解说", "category": "fallback", "gender": "male", "accent": "zh-CN", "language": "zh-CN", "preview_url": ""},
        {"voice_id": "edge-zh-yunxi", "name": "云希 · 年轻动感", "category": "fallback", "gender": "male", "accent": "zh-CN", "language": "zh-CN", "preview_url": ""},
        {"voice_id": "edge-zh-yunyang", "name": "云扬 · 专业播报", "category": "fallback", "gender": "male", "accent": "zh-CN", "language": "zh-CN", "preview_url": ""},
        {"voice_id": "edge-zh-xiaoxiao", "name": "晓晓 · 自然女声", "category": "fallback", "gender": "female", "accent": "zh-CN", "language": "zh-CN", "preview_url": ""},
        {"voice_id": "edge-zh-xiaoyi", "name": "晓伊 · 温暖女声", "category": "fallback", "gender": "female", "accent": "zh-CN", "language": "zh-CN", "preview_url": ""},
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

@app.post("/api/voice/one-shot")
def voice_one_shot():
    """
    VOICE DIRECTOR V2.4 · ANIMATION FIRST
    Generate the complete narration in ONE provider request.
    The final audio is the source of truth; captions are created afterwards
    by transcribing this exact audio through /api/caption.
    """
    if not authorized():
        return jsonify({"ok": False, "error": "Unauthorized"}), 401
    data = request.get_json(silent=True) or {}
    text = str(data.get("text") or "").strip()
    mode = str(data.get("mode") or "ai_male")
    voice_id = str(data.get("voice_id") or "").strip()
    try:
        speed = max(0.75, min(1.25, float(data.get("speed") or 1.0)))
    except Exception:
        speed = 1.0
    style = str(data.get("style") or "documentary")

    if not text:
        return jsonify({"ok": False, "error": "Text required"}), 400
    if len(text) > 10000:
        return jsonify({"ok": False, "error": "ONE_SHOT_TEXT_TOO_LONG"}), 413
    if mode == "clone" and not ELEVENLABS_API_KEY:
        return jsonify({"ok": False, "error": "VOICE_CLONE_REQUIRES_ELEVENLABS"}), 503

    work = tempfile.mkdtemp(prefix="sagi_voice_one_shot_")
    path = Path(work) / "one_shot.mp3"
    try:
        synthesize_voice(text, mode, voice_id, path, speed, style)
        duration = audio_duration_seconds(path)
        if duration <= 0.1 or not path.exists() or path.stat().st_size < 1000:
            raise RuntimeError("ONE_SHOT_EMPTY_AUDIO")
        resp = send_file(path, mimetype="audio/mpeg", as_attachment=False)
        resp.headers["X-SAGI-Voice-Complete"] = "1"
        resp.headers["X-SAGI-Voice-Mode"] = "one-shot"
        resp.headers["X-SAGI-Voice-Duration"] = str(round(duration, 3))
        resp.headers["Access-Control-Expose-Headers"] = "X-SAGI-Voice-Complete, X-SAGI-Voice-Mode, X-SAGI-Voice-Duration"
        resp.call_on_close(lambda: shutil.rmtree(work, ignore_errors=True))
        return resp
    except Exception as e:
        shutil.rmtree(work, ignore_errors=True)
        return jsonify({"ok": False, "error": str(e)[:700]}), 500


@app.post("/api/voice/preview")
def voice_preview():
    if not authorized():
        return jsonify({"ok": False, "error": "Unauthorized"}), 401
    data = request.get_json(silent=True) or {}
    text = str(data.get("text") or "").strip()
    mode = str(data.get("mode") or "ai_male")
    voice_id = str(data.get("voice_id") or "").strip()
    speed = float(data.get("speed") or 1.0)
    style = str(data.get("style") or "football")
    if not text:
        return jsonify({"ok": False, "error": "Text required"}), 400
    work = tempfile.mkdtemp(prefix="sagi_voice_preview_")
    path = Path(work) / "preview.mp3"
    try:
        preview_path, meta = synthesize_voice_timeline(
            text, mode, voice_id, Path(work), speed, style,
            clip_duration=0, raw_timeline=None, sync_mode="natural",
        )
        resp = send_file(preview_path, mimetype="audio/mp4", as_attachment=False)
        resp.headers["X-SAGI-Voice-Complete"] = "1"
        resp.headers["X-SAGI-Voice-Coverage"] = "100"
        resp.headers["X-SAGI-Voice-Segments"] = str(meta.get("segments") or 0)
        resp.headers["X-SAGI-Voice-Duration"] = str(meta.get("duration") or 0)
        resp.headers["Access-Control-Expose-Headers"] = "X-SAGI-Voice-Complete, X-SAGI-Voice-Coverage, X-SAGI-Voice-Segments, X-SAGI-Voice-Duration"
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

    try:
        voice_timeline = json.loads(request.form.get("voice_timeline") or "[]")
        if not isinstance(voice_timeline, list):
            voice_timeline = []
    except Exception:
        voice_timeline = []

    try:
        scene_plan = json.loads(request.form.get("scene_plan") or "[]")
        if not isinstance(scene_plan, list):
            scene_plan = []
    except Exception:
        scene_plan = []

    try:
        meaning_audit = json.loads(request.form.get("meaning_audit") or "{}")
        if not isinstance(meaning_audit, dict):
            meaning_audit = {}
    except Exception:
        meaning_audit = {}
    meaning_first = str(request.form.get("meaning_first") or "false").lower() in ("1", "true", "yes")

    options = {
        "start": request.form.get("start") or "0",
        "duration": request.form.get("duration") or "15",
        "aspect": request.form.get("aspect") or "9:16",
        "quality": request.form.get("quality") or "fast",
        "captions": captions[:300],
        "narration": request.form.get("narration") or "",
        "voice_timeline": voice_timeline,
        "voice_mode": request.form.get("voice_mode") or "none",
        "voice_id": request.form.get("voice_id") or "",
        "voice_speed": request.form.get("voice_speed") or "1",
        "voice_style": request.form.get("voice_style") or "football",
        "voice_sync": request.form.get("voice_sync") or "fit",
        "meaning_first": meaning_first,
        "meaning_audit": meaning_audit,
        "visual_sync": request.form.get("visual_sync") or "auto",
        "visual_sync_max_hold": request.form.get("visual_sync_max_hold") or "3",
        "scene_plan": scene_plan[:60],
        "voice_volume": request.form.get("voice_volume") or "1",
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


@app.post("/api/market/submit")
def market_submit():
    if not origin_allowed():
        return jsonify({"ok": False, "error": "Origin not allowed"}), 403
    if not market_cloud_ready():
        return jsonify({"ok": False, "error": "Market cloud is not configured"}), 503
    if not market_rate_allowed():
        return jsonify({"ok": False, "error": "提交过于频繁，请稍后再试"}), 429

    body = request.get_json(silent=True) or {}
    photo = str(body.get("photo") or "")
    if photo and (not photo.startswith("data:image/jpeg;base64,") or len(photo) > 650000):
        return jsonify({"ok": False, "error": "照片格式或大小不符合要求"}), 400

    name = _market_clean_text(body.get("name"), 80)
    seller = _market_clean_text(body.get("seller"), 60)
    contact = _market_clean_text(body.get("contact"), 80)
    if not name or not seller or not contact:
        return jsonify({"ok": False, "error": "商品名称、卖家和联系方式不能为空"}), 400

    submission_id = secrets.token_hex(16)
    slug = "market-sub-" + submission_id
    payload = {
        "id": submission_id,
        "type": "secondhand",
        "name": name,
        "category": _market_clean_text(body.get("category"), 30),
        "seller": seller,
        "contact": contact,
        "size": _market_clean_text(body.get("size"), 30),
        "condition": _market_clean_text(body.get("condition"), 30),
        "city": _market_clean_text(body.get("city"), 40),
        "price": max(0, min(999999, float(body.get("price") or 0))) if str(body.get("price") or "0").replace(".", "", 1).isdigit() else 0,
        "notes": _market_clean_text(body.get("notes"), 800),
        "photo": photo,
        "createdAt": iso(),
        "source": "seller-intake-v1.1",
    }

    try:
        _market_rpc(
            "sagi_claim_event",
            {
                "p_slug": slug,
                "p_token": SAGI_MARKET_WRITE_TOKEN,
                "p_payload": payload,
            },
        )
        def append_item(items):
            rows = [x for x in items if isinstance(x, dict) and x.get("id") != submission_id]
            rows.append({
                "id": submission_id,
                "slug": slug,
                "status": "pending",
                "name": name,
                "category": payload["category"],
                "seller": seller,
                "city": payload["city"],
                "price": payload["price"],
                "createdAt": payload["createdAt"],
            })
            return rows
        _market_update_inbox(append_item)
    except Exception as exc:
        return jsonify({"ok": False, "error": "云端收货箱暂不可用", "detail": str(exc)[:180]}), 503

    return jsonify({
        "ok": True,
        "submissionId": submission_id,
        "message": "提交成功，等待 SAGI 审核",
    })


@app.get("/api/market/inbox")
def market_inbox():
    if not authorized():
        return jsonify({"ok": False, "error": "Unauthorized"}), 401
    if not market_cloud_ready():
        return jsonify({"ok": False, "error": "Market cloud is not configured"}), 503
    try:
        row = _market_ensure_inbox()
        index_items = list(((row or {}).get("payload") or {}).get("items") or [])
        pending = [x for x in index_items if isinstance(x, dict) and x.get("status") == "pending"]
        pending = sorted(pending, key=lambda x: str(x.get("createdAt") or ""), reverse=True)[:20]
        result = []
        for item in pending:
            sub = _market_get(str(item.get("slug") or ""))
            if sub and isinstance(sub.get("payload"), dict):
                result.append(sub["payload"])
        return jsonify({
            "ok": True,
            "items": result,
            "count": len(result),
            "revision": (row or {}).get("revision"),
        })
    except Exception as exc:
        return jsonify({"ok": False, "error": "读取收货箱失败", "detail": str(exc)[:180]}), 503


@app.post("/api/market/decision")
def market_decision():
    if not authorized():
        return jsonify({"ok": False, "error": "Unauthorized"}), 401
    body = request.get_json(silent=True) or {}
    submission_id = _market_clean_text(body.get("id"), 40)
    decision = _market_clean_text(body.get("decision"), 20)
    if not submission_id or decision not in ("approved", "rejected"):
        return jsonify({"ok": False, "error": "Invalid decision"}), 400

    try:
        changed = {"ok": False}
        def decide(items):
            rows = []
            for raw in items:
                item = dict(raw) if isinstance(raw, dict) else {}
                if item.get("id") == submission_id:
                    item["status"] = decision
                    item["decidedAt"] = iso()
                    changed["ok"] = True
                rows.append(item)
            return rows
        _market_update_inbox(decide)
        if not changed["ok"]:
            return jsonify({"ok": False, "error": "Submission not found"}), 404
        return jsonify({"ok": True, "id": submission_id, "decision": decision})
    except Exception as exc:
        return jsonify({"ok": False, "error": "更新审核状态失败", "detail": str(exc)[:180]}), 503


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
    raw = COBALT_HOSTPORT.strip().rstrip("/")
    if raw.startswith("http://") or raw.startswith("https://"):
        return raw
    # Render injects RENDER_EXTERNAL_HOSTNAME without a scheme.
    if raw.endswith(".onrender.com"):
        return "https://" + raw
    return "http://" + raw

def _cobalt_items(payload):
    status = str(payload.get("status") or "")
    if status in ("tunnel", "redirect"):
        url = payload.get("url")
        return ([{"type": "video", "url": url}] if url else []), payload.get("filename") or ""
    if status == "picker":
        rows = []
        for item in payload.get("picker") or []:
            url = item.get("url")
            kind = str(item.get("type") or "photo")
            if url and kind in ("photo", "video", "gif"):
                rows.append({"type": kind, "url": url})
        return rows, payload.get("filename") or ""
    if status == "error":
        err = payload.get("error") or {}
        code = err.get("code") or "cobalt_error"
        raise RuntimeError("COBALT_ERROR: " + str(code))
    if status == "local-processing":
        raise RuntimeError("COBALT_LOCAL_PROCESSING_UNSUPPORTED")
    raise RuntimeError("COBALT_INVALID_RESPONSE")


def run_cobalt_download(job_id, url, wanted_name, terminal=True):
    with jobs_lock:
        job = jobs.get(job_id)
        if not job:
            return False, "JOB_MISSING"
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
                "youtubeVideoCodec": "h264",
                "youtubeVideoContainer": "mp4",
            },
            timeout=(8, 45),
        )
        if r.status_code == 429:
            raise RuntimeError("COBALT_RATE_LIMIT")
        r.raise_for_status()
        payload = r.json()
        items, cobalt_name = _cobalt_items(payload)
        if not items:
            raise RuntimeError("COBALT_NO_MEDIA")

        with jobs_lock:
            job = jobs.get(job_id)
            if job:
                job["status"] = "cobalt_fetching"
                job["updated_at"] = iso()

        max_bytes = MAX_FILE_MB * 1024 * 1024
        total = 0
        saved = []
        for idx, item in enumerate(items, start=1):
            media_url = item["url"]
            kind = item.get("type") or "photo"
            media_resp = requests.get(media_url, stream=True, timeout=(8, 60))
            media_resp.raise_for_status()
            content_type = (media_resp.headers.get("Content-Type") or "").lower()
            if kind in ("video", "gif") or "video/" in content_type:
                ext = ".mp4"
            elif "png" in content_type:
                ext = ".png"
            elif "webp" in content_type:
                ext = ".webp"
            else:
                ext = ".jpg"
            path = Path(work) / f"{idx:02d}{ext}"
            size = 0
            with path.open("wb") as out:
                for chunk in media_resp.iter_content(chunk_size=256 * 1024):
                    if not chunk:
                        continue
                    size += len(chunk)
                    total += len(chunk)
                    if total > max_bytes:
                        raise RuntimeError(f"媒体超过云端限制 {MAX_FILE_MB}MB")
                    out.write(chunk)
            if size > 0:
                saved.append((kind, path))

        if not saved:
            raise RuntimeError("COBALT_EMPTY_FILE")

        base_name = safe_name(wanted_name or cobalt_name or "SAGI_VIDEO")
        if len(saved) == 1:
            kind, src = saved[0]
            filename = base_name
            if "." not in filename:
                filename += src.suffix
            dst = Path(work) / filename
            if src.resolve() != dst.resolve():
                src.replace(dst)
            media_path = dst
            media_kind = "video" if kind in ("video", "gif") else "image"
            count = 1
        else:
            filename = base_name + "_CAROUSEL.zip"
            media_path = Path(work) / filename
            with zipfile.ZipFile(media_path, "w", compression=zipfile.ZIP_STORED) as zf:
                for idx, (_, src) in enumerate(saved, start=1):
                    zf.write(src, arcname=f"{idx:02d}{src.suffix}")
            for _, src in saved:
                src.unlink(missing_ok=True)
            media_kind = "carousel"
            count = len(saved)

        with jobs_lock:
            job = jobs.get(job_id)
            if not job:
                shutil.rmtree(work, ignore_errors=True)
                return False, "JOB_MISSING"
            job.update({
                "status": "ready",
                "updated_at": iso(),
                "path": str(media_path),
                "workdir": work,
                "filename": filename,
                "title": cobalt_name or filename,
                "size": media_path.stat().st_size,
                "strategy": "cobalt",
                "mediaKind": media_kind,
                "fileCount": count,
                "error": "",
                "errorCode": "",
            })
        return True, ""
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
                if terminal:
                    job.update({
                        "status": "failed",
                        "updated_at": iso(),
                        "strategy": "cobalt",
                        "error": msg[:700],
                        "errorCode": code,
                    })
                else:
                    job.update({
                        "status": "downloading",
                        "updated_at": iso(),
                        "strategy": "sagi_fallback",
                        "error": "",
                        "errorCode": "",
                        "cobaltError": msg[:300],
                    })
        return False, msg

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
