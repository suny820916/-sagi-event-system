from flask import Flask, request, send_file, jsonify, after_this_request
from urllib.parse import urlparse
from pathlib import Path
import tempfile, shutil, socket, os
import yt_dlp

app = Flask(__name__)

def lan_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"

def allowed_instagram(url):
    try:
        host = (urlparse(url).hostname or "").lower().strip(".")
        return host == "instagram.com" or host.endswith(".instagram.com")
    except Exception:
        return False

@app.after_request
def cors(resp):
    resp.headers["Access-Control-Allow-Origin"] = "*"
    resp.headers["Cache-Control"] = "no-store"
    return resp

@app.get("/")
@app.get("/health")
def health():
    return jsonify({
        "ok": True,
        "service": "SAGI LOCAL BRIDGE",
        "engine": "yt-dlp",
        "lan": f"http://{lan_ip()}:8765",
        "instagram": True
    })

@app.get("/download")
def download():
    url = (request.args.get("url") or "").strip()
    wanted_name = (request.args.get("name") or "").strip()
    if not allowed_instagram(url):
        return jsonify({"ok": False, "error": "Only Instagram URLs are enabled in this bridge build."}), 400

    work = tempfile.mkdtemp(prefix="sagi_ins_")
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
    }

    try:
        with yt_dlp.YoutubeDL(opts) as ydl:
            info = ydl.extract_info(url, download=True)

        files = [p for p in Path(work).iterdir() if p.is_file() and not p.name.endswith((".part", ".ytdl"))]
        if not files:
            shutil.rmtree(work, ignore_errors=True)
            return jsonify({"ok": False, "error": "No downloadable media returned by Instagram."}), 502

        media = max(files, key=lambda p: p.stat().st_size)
        ext = media.suffix or ".mp4"
        clean = "".join(ch for ch in wanted_name if ch not in '\\/:*?"<>|').strip()
        if clean:
            if not clean.lower().endswith(ext.lower()):
                clean += ext
            download_name = clean[:120]
        else:
            download_name = media.name[:120]

        @after_this_request
        def cleanup(response):
            try:
                shutil.rmtree(work, ignore_errors=True)
            except Exception:
                pass
            return response

        return send_file(media, as_attachment=True, download_name=download_name, conditional=True)
    except Exception as e:
        shutil.rmtree(work, ignore_errors=True)
        return jsonify({"ok": False, "error": str(e)}), 500

if __name__ == "__main__":
    ip = lan_ip()
    print("")
    print("==============================================")
    print(" SAGI LOCAL BRIDGE · INSTAGRAM DIRECT DOWNLOAD")
    print("==============================================")
    print(f" Phone Bridge URL: http://{ip}:8765")
    print(" Keep this window open while downloading.")
    print("")
    app.run(host="0.0.0.0", port=8765, threaded=True)
