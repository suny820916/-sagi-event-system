import json
import os
import platform
import socket
import tempfile
import time
from pathlib import Path

import requests
import yt_dlp

CLOUD = "https://sagi-cloud-bridge-suny820916.onrender.com"
BASE = Path(__file__).resolve().parent
CONFIG = BASE / "worker-config.json"
COOKIES = BASE / "cookies.txt"

def worker_id():
    return f"{platform.node() or socket.gethostname() or 'SAGI-PC'}"

def load_config():
    if CONFIG.exists():
        try:
            data = json.loads(CONFIG.read_text(encoding="utf-8"))
            if data.get("token"):
                return data
        except Exception:
            pass
    return {}

def save_config(data):
    CONFIG.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

def pair():
    print("")
    print("SAGI REMOTE WORKER · FIRST PAIRING")
    print("Open CONTENT OS > DOWN > SAGI CLOUD and generate a 6-digit pairing code.")
    print("")
    code = input("Enter pairing code: ").strip()
    r = requests.post(
        CLOUD + "/api/worker/pair/claim",
        json={"code": code, "workerId": worker_id()},
        timeout=20,
    )
    data = r.json()
    if not r.ok or not data.get("ok"):
        raise RuntimeError(data.get("error") or f"Pairing failed ({r.status_code})")
    cfg = {"token": data["token"], "cloud": data.get("cloud") or CLOUD, "workerId": worker_id()}
    save_config(cfg)
    print("Paired successfully. This computer is now remembered.")
    return cfg

def headers(cfg):
    return {
        "Authorization": "Bearer " + cfg["token"],
        "X-SAGI-Worker": cfg.get("workerId") or worker_id(),
    }

def download_instagram(url, wanted_name):
    work = Path(tempfile.mkdtemp(prefix="sagi_remote_"))
    outtmpl = str(work / "%(title).80s_%(id)s.%(ext)s")
    opts = {
        "format": "best[ext=mp4]/best",
        "outtmpl": outtmpl,
        "noplaylist": True,
        "quiet": False,
        "no_warnings": False,
        "restrictfilenames": True,
        "retries": 3,
        "fragment_retries": 3,
        "socket_timeout": 25,
        "sleep_interval_requests": 1,
        "max_sleep_interval": 3,
    }
    if COOKIES.exists():
        opts["cookiefile"] = str(COOKIES)

    with yt_dlp.YoutubeDL(opts) as ydl:
        info = ydl.extract_info(url, download=True)

    files = [
        p for p in work.iterdir()
        if p.is_file() and not p.name.endswith((".part", ".ytdl", ".json"))
    ]
    if not files:
        raise RuntimeError("No downloadable Instagram media returned.")
    media = max(files, key=lambda p: p.stat().st_size)
    name = (wanted_name or media.name).strip() or media.name
    if "." not in name:
        name += media.suffix or ".mp4"
    return work, media, info, name

def fail(cfg, job_id, error):
    try:
        requests.post(
            cfg["cloud"] + f"/api/worker/jobs/{job_id}/fail",
            headers=headers(cfg),
            json={"error": str(error)},
            timeout=20,
        )
    except Exception:
        pass

def complete(cfg, job_id, media, info, name):
    with media.open("rb") as f:
        r = requests.post(
            cfg["cloud"] + f"/api/worker/jobs/{job_id}/complete",
            headers=headers(cfg),
            files={"file": (name, f, "video/mp4")},
            data={"name": name, "title": info.get("title") or name},
            timeout=300,
        )
    data = r.json()
    if not r.ok or not data.get("ok"):
        raise RuntimeError(data.get("error") or f"Upload failed ({r.status_code})")

def main():
    cfg = load_config()
    if not cfg:
        cfg = pair()

    print("")
    print("==============================================")
    print(" SAGI REMOTE WORKER · INSTAGRAM")
    print("==============================================")
    print("Cloud :", cfg.get("cloud") or CLOUD)
    print("Worker:", cfg.get("workerId") or worker_id())
    print("Status: ONLINE · Keep this window open")
    if COOKIES.exists():
        print("Cookies: cookies.txt loaded")
    print("")

    while True:
        try:
            r = requests.get(
                cfg["cloud"] + "/api/worker/jobs/next",
                headers=headers(cfg),
                timeout=20,
            )
            if r.status_code == 401:
                print("Worker authorization expired. Re-pairing...")
                try:
                    CONFIG.unlink()
                except Exception:
                    pass
                cfg = pair()
                continue

            data = r.json()
            if r.ok and data.get("ok") and data.get("job"):
                job = data["job"]
                print("")
                print("JOB:", job["id"])
                print("URL:", job["url"])
                work = None
                try:
                    work, media, info, name = download_instagram(job["url"], job.get("name"))
                    print("Downloaded:", media.name)
                    print("Uploading to SAGI CLOUD...")
                    complete(cfg, job["id"], media, info, name)
                    print("DONE · Phone can download now.")
                except Exception as e:
                    print("FAILED:", e)
                    fail(cfg, job["id"], e)
                finally:
                    if work:
                        import shutil
                        shutil.rmtree(work, ignore_errors=True)
            else:
                time.sleep(3)
        except KeyboardInterrupt:
            print("\nSAGI REMOTE WORKER stopped.")
            break
        except Exception as e:
            print("Connection retry:", e)
            time.sleep(5)

if __name__ == "__main__":
    main()
