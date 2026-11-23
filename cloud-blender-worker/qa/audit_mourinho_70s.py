#!/usr/bin/env python3
"""Non-acceptance technical audit for the locked 70s Mourinho production master.
Does not claim Teactics visual similarity without direct source/frame review.
"""
import json, subprocess, sys
from pathlib import Path

def probe(path):
    return json.loads(subprocess.check_output([
        "ffprobe","-v","error","-show_entries",
        "format=duration:stream=codec_type,width,height,nb_frames",
        "-of","json",str(path)], text=True))

def top_dark_fraction(frame_path, top_fraction=0.20, threshold=25):
    """Measure black space, not pitch clipping; requires visual confirmation."""
    width, height = 90, 160
    raw = subprocess.check_output([
        "ffmpeg", "-v", "error", "-i", str(frame_path),
        "-vf", f"scale={width}:{height},format=gray",
        "-frames:v", "1", "-f", "rawvideo", "-"
    ])
    n = width * int(height * top_fraction)
    if len(raw) < n:
        raise ValueError(f"could not decode frame {frame_path}")
    return round(sum(v < threshold for v in raw[:n]) / n, 4)

def audit(video, report, frame_dir, out):
    video, report, frame_dir, out = map(Path,(video,report,frame_dir,out))
    r=json.loads(report.read_text(encoding="utf-8"))
    p=probe(video)
    duration=float(p["format"]["duration"])
    images=sorted(frame_dir.glob("*.jpg"))
    errors=[]
    if abs(duration-70)>0.05: errors.append(f"duration {duration:.3f} != 70")
    expected={f"{t}.jpg" for t in (4,12,20,28,36,44,52,60,68)}
    actual={f.name for f in images}
    if actual!=expected: errors.append(f"critical frame timestamps mismatch: missing={sorted(expected-actual)}, extra={sorted(actual-expected)}")
    if any(f.stat().st_size==0 for f in images): errors.append("empty critical frame")
    if not any(s.get("codec_type")=="video" for s in p["streams"]): errors.append("no video stream")
    if not r.get("valid",False) or r.get("errors"): errors.append("engine report invalid")
    if r.get("full_video_decode")!="PASS": errors.append("full decode gate not confirmed")
    if r.get("v42_projection_gate",{}).get("sampled_frames")!=2100: errors.append("projection gate frame count not 2100")
    if r.get("v42_projection_gate",{}).get("outside_safe_frames"): errors.append("projection safe frame violations")
    if not all(s.get("width",0)>0 and s.get("height",0)>0 for s in p["streams"] if s.get("codec_type")=="video"): errors.append("invalid video dimensions")
    dark_top = {}
    for frame in images:
        try:
            dark_top[frame.stem] = top_dark_fraction(frame)
        except (subprocess.CalledProcessError, ValueError) as exc:
            errors.append(f"dark-region audit failed for {frame.name}: {exc}")
    dark_alerts = [t for t, fraction in dark_top.items() if fraction >= 0.90]
    result={
      "technical_gate":"FAIL" if errors else "PASS",
      "top_20pct_dark_fraction_by_second":dark_top,
      "dark_top_visual_review_seconds":dark_alerts,
      "dark_region_interpretation":"Black space is not proof of clipping; review pitch and tactical subjects visually.",
      "duration_sec":duration,"critical_frames":len(images),
      "errors":errors,
      "teactics_reference":"SAGI_CLOUD_RENDER.mp4",
      "direct_visual_comparison":"NOT_PERFORMED",
      "visual_director_acceptance":"PENDING",
      "similarity_percent":None,
      "review_required":[
        "open entire 70s MP4 and inspect motion continuity",
        "compare Teactics source and candidate at matched tactical beats",
        "check yellow Chinese titles, camera height, subject scale, pitch coverage",
        "check ball visibility, relation framing, defensive reactions and clipping"]
    }
    out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding="utf-8")
    print(json.dumps(result,ensure_ascii=False,indent=2))
    return 1 if errors else 0

if __name__=="__main__":
    if len(sys.argv)!=5:
        sys.exit("usage: audit_mourinho.py final.mp4 execution_report.json critical_frames/ qa.json")
    sys.exit(audit(*sys.argv[1:]))
