from __future__ import annotations

import math
import os
import shutil
import subprocess
import tempfile
import time
import uuid
from collections import Counter
from pathlib import Path
from threading import Lock, Thread

import imageio_ffmpeg
import numpy as np
import requests
from flask import Blueprint, jsonify, request, send_file


MODEL_URL = (
    os.getenv("SAGI_MATCH_MODEL_URL")
    or "https://huggingface.co/unileon-robotics/YOLO11-ONNX/resolve/main/yolo11n.onnx"
)
MODEL_DIR = Path(tempfile.gettempdir()) / "sagi_match_models"
MODEL_PATH = MODEL_DIR / "yolo11n.onnx"
MAX_UPLOAD_MB = max(10, min(200, int(os.getenv("SAGI_MATCH_MAX_MB") or "80")))
ANALYSIS_FPS = max(0.25, min(2.0, float(os.getenv("SAGI_MATCH_FPS") or "1")))
MAX_SECONDS = max(15, min(180, int(os.getenv("SAGI_MATCH_MAX_SECONDS") or "90")))
CONFIDENCE = max(0.15, min(0.8, float(os.getenv("SAGI_MATCH_CONF") or "0.28")))
TRACK_DISTANCE = max(0.04, min(0.25, float(os.getenv("SAGI_MATCH_TRACK_DISTANCE") or "0.12")))
TRACK_MAX_AGE = max(2, min(8, int(os.getenv("SAGI_MATCH_TRACK_MAX_AGE") or "5")))
TRACK_COLOR_WEIGHT = max(0.0, min(0.5, float(os.getenv("SAGI_MATCH_TRACK_COLOR_WEIGHT") or "0.18")))
BALL_MAX_AGE = max(1, min(5, int(os.getenv("SAGI_MATCH_BALL_MAX_AGE") or "2")))
POSSESSION_MIN_SAMPLES = max(2, min(12, int(os.getenv("SAGI_MATCH_POSSESSION_MIN_SAMPLES") or "4")))
MATCH_VERSION = "1.1.2-tracking-core"

_jobs = {}
_jobs_lock = Lock()
_model_lock = Lock()
_session = None
_input_name = ""
_input_h = 480
_input_w = 640


def _ensure_model() -> Path:
    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    if MODEL_PATH.exists() and MODEL_PATH.stat().st_size > 5_000_000:
        return MODEL_PATH

    tmp = MODEL_PATH.with_suffix(".download")
    with requests.get(MODEL_URL, stream=True, timeout=(10, 90)) as response:
        response.raise_for_status()
        with tmp.open("wb") as out:
            for chunk in response.iter_content(chunk_size=1024 * 1024):
                if chunk:
                    out.write(chunk)
    tmp.replace(MODEL_PATH)
    return MODEL_PATH


def _get_session():
    global _session, _input_name, _input_h, _input_w
    import onnxruntime as ort
    with _model_lock:
        if _session is not None:
            return _session

        model_path = _ensure_model()
        options = ort.SessionOptions()
        options.intra_op_num_threads = 1
        options.inter_op_num_threads = 1
        options.enable_mem_pattern = False
        options.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL

        _session = ort.InferenceSession(
            str(model_path),
            sess_options=options,
            providers=["CPUExecutionProvider"],
        )
        inp = _session.get_inputs()[0]
        _input_name = inp.name
        shape = inp.shape
        if len(shape) == 4:
            if isinstance(shape[2], int):
                _input_h = int(shape[2])
            if isinstance(shape[3], int):
                _input_w = int(shape[3])
        return _session


def _nms(boxes: np.ndarray, scores: np.ndarray, iou_threshold: float = 0.5, limit: int = 40):
    if len(boxes) == 0:
        return []
    order = scores.argsort()[::-1]
    keep = []
    while order.size and len(keep) < limit:
        i = int(order[0])
        keep.append(i)
        if order.size == 1:
            break

        xx1 = np.maximum(boxes[i, 0], boxes[order[1:], 0])
        yy1 = np.maximum(boxes[i, 1], boxes[order[1:], 1])
        xx2 = np.minimum(boxes[i, 2], boxes[order[1:], 2])
        yy2 = np.minimum(boxes[i, 3], boxes[order[1:], 3])

        w = np.maximum(0.0, xx2 - xx1)
        h = np.maximum(0.0, yy2 - yy1)
        inter = w * h
        area_i = max(1e-6, (boxes[i, 2] - boxes[i, 0]) * (boxes[i, 3] - boxes[i, 1]))
        area_o = np.maximum(
            1e-6,
            (boxes[order[1:], 2] - boxes[order[1:], 0])
            * (boxes[order[1:], 3] - boxes[order[1:], 1]),
        )
        iou = inter / (area_i + area_o - inter + 1e-6)
        order = order[1:][iou < iou_threshold]
    return keep


def _detect(frame: np.ndarray):
    session = _get_session()
    blob = frame.astype(np.float32) / 255.0
    blob = np.transpose(blob, (2, 0, 1))[None, ...]
    out = session.run(None, {_input_name: blob})[0]
    pred = out[0]
    if pred.ndim != 2:
        return [], []
    if pred.shape[0] in (84, 85):
        pred = pred.T

    boxes_xywh = pred[:, :4]
    class_scores = pred[:, 4:]
    if class_scores.shape[1] < 33:
        return [], []

    results = {}
    for class_id in (0, 32):
        scores = class_scores[:, class_id]
        mask = scores >= CONFIDENCE
        if not np.any(mask):
            results[class_id] = []
            continue

        b = boxes_xywh[mask].copy()
        s = scores[mask].copy()
        xyxy = np.empty_like(b)
        xyxy[:, 0] = b[:, 0] - b[:, 2] / 2
        xyxy[:, 1] = b[:, 1] - b[:, 3] / 2
        xyxy[:, 2] = b[:, 0] + b[:, 2] / 2
        xyxy[:, 3] = b[:, 1] + b[:, 3] / 2
        xyxy[:, [0, 2]] = np.clip(xyxy[:, [0, 2]], 0, _input_w - 1)
        xyxy[:, [1, 3]] = np.clip(xyxy[:, [1, 3]], 0, _input_h - 1)

        keep = _nms(xyxy, s, 0.5, 36 if class_id == 0 else 5)
        rows = []
        for idx in keep:
            x1, y1, x2, y2 = xyxy[idx].tolist()
            rows.append(
                {
                    "box": [float(x1), float(y1), float(x2), float(y2)],
                    "score": float(s[idx]),
                    "cx": float((x1 + x2) / 2 / _input_w),
                    "cy": float(y2 / _input_h),
                    "center_y": float((y1 + y2) / 2 / _input_h),
                }
            )
        results[class_id] = rows

    return results.get(0, []), results.get(32, [])


def _jersey_rgb(frame: np.ndarray, box):
    x1, y1, x2, y2 = [int(v) for v in box]
    w = max(1, x2 - x1)
    h = max(1, y2 - y1)
    xa = max(0, int(x1 + 0.25 * w))
    xb = min(_input_w, int(x1 + 0.75 * w))
    ya = max(0, int(y1 + 0.18 * h))
    yb = min(_input_h, int(y1 + 0.52 * h))
    crop = frame[ya:yb, xa:xb]
    if crop.size == 0:
        return None
    pix = crop.reshape(-1, 3)
    brightness = pix.mean(axis=1)
    keep = pix[(brightness > 35) & (brightness < 235)]
    if len(keep) < 20:
        keep = pix
    if len(keep) == 0:
        return None
    return np.median(keep, axis=0).astype(np.float32)


def _color_distance(a, b):
    if a is None or b is None:
        return 0.0
    return float(np.linalg.norm(np.asarray(a, dtype=np.float32) - np.asarray(b, dtype=np.float32)) / 441.673)


def _predict_track_position(track, frame_no):
    positions = track.get("positions") or []
    if not positions:
        return track.get("last_pos") or (0.5, 0.5)
    _, x2, y2 = positions[-1]
    if len(positions) < 2:
        return float(x2), float(y2)

    f1, x1, y1 = positions[-2]
    f2, x2, y2 = positions[-1]
    dt = max(1, int(f2) - int(f1))
    age = max(0, int(frame_no) - int(f2))
    vx = (float(x2) - float(x1)) / dt
    vy = (float(y2) - float(y1)) / dt
    px = min(1.0, max(0.0, float(x2) + vx * age))
    py = min(1.0, max(0.0, float(y2) + vy * age))
    return px, py


def _track_color(track):
    colors = track.get("colors") or []
    if not colors:
        return None
    return np.median(np.vstack(colors[-6:]), axis=0)


def _match_tracks(active, people, frame_no, next_id):
    candidates = []
    for tid, track in active.items():
        age = int(frame_no) - int(track["last_frame"])
        if age > TRACK_MAX_AGE:
            continue

        tx, ty = _predict_track_position(track, frame_no)
        track_color = _track_color(track)
        gate = min(0.34, TRACK_DISTANCE * (1.0 + 0.55 * max(0, age - 1)))

        for j, person in enumerate(people):
            d = math.hypot(tx - person["cx"], ty - person["cy"])
            if d > gate:
                continue

            person_color = person.get("jersey_rgb")
            color_d = _color_distance(track_color, person_color)
            if track_color is not None and person_color is not None and color_d > 0.42:
                continue

            cost = d + TRACK_COLOR_WEIGHT * color_d
            candidates.append((cost, d, color_d, tid, j))

    candidates.sort()
    used_tracks = set()
    used_people = set()
    assignments = {}
    for _, _, _, tid, j in candidates:
        if tid in used_tracks or j in used_people:
            continue
        used_tracks.add(tid)
        used_people.add(j)
        assignments[j] = tid

    for j in range(len(people)):
        if j not in assignments:
            assignments[j] = next_id
            next_id += 1
    return assignments, next_id


def _update_ball_track(ball_track, balls, frame_no):
    if balls:
        predicted = None
        if ball_track and ball_track.get("positions"):
            predicted = _predict_track_position(ball_track, frame_no)

        def ball_cost(item):
            if predicted is None:
                return -float(item.get("score") or 0.0)
            bx = float(item["cx"])
            by = float(item.get("center_y", item["cy"]))
            return math.hypot(predicted[0] - bx, predicted[1] - by) - 0.04 * float(item.get("score") or 0.0)

        ball = min(balls, key=ball_cost)
        bx = float(ball["cx"])
        by = float(ball.get("center_y", ball["cy"]))
        if ball_track is None:
            ball_track = {"positions": []}
        ball_track["positions"].append((frame_no, bx, by))
        ball_track["last_frame"] = frame_no
        ball_track["last_pos"] = (bx, by)
        return ball_track, {"cx": bx, "cy": by, "observed": True}

    if ball_track and ball_track.get("positions"):
        age = int(frame_no) - int(ball_track.get("last_frame", frame_no))
        if age <= BALL_MAX_AGE:
            bx, by = _predict_track_position(ball_track, frame_no)
            return ball_track, {"cx": bx, "cy": by, "observed": False}

    return ball_track, None


def _expected_players(match_format):
    raw = str(match_format or "").lower()
    try:
        value = int(raw.split("v", 1)[0])
        return value if value in (5, 6, 7, 8, 9, 10, 11) else 0
    except Exception:
        return 0


def _stable_track_ids(tracks, team_assignments, frame_no, match_format):
    expected = _expected_players(match_format)
    min_visible = max(2, int(math.ceil(max(1, frame_no) * 0.25)))
    selected = set()

    for team in (0, 1):
        rows = []
        for tid, track in tracks.items():
            if team_assignments.get(tid) != team:
                continue
            visible = len(track.get("positions") or [])
            if visible < min_visible:
                continue
            rows.append((visible, int(track.get("last_frame") or 0), tid))
        rows.sort(reverse=True)
        limit = expected if expected > 0 else len(rows)
        selected.update(tid for _, _, tid in rows[:limit])

    return selected


def _kmeans(features: np.ndarray, k: int):
    if len(features) <= k:
        return np.arange(len(features)) % k, features[:k]
    center_ids = [0]
    while len(center_ids) < k:
        chosen = features[center_ids]
        dist = ((features[:, None, :] - chosen[None, :, :]) ** 2).sum(axis=2)
        nearest = dist.min(axis=1)
        center_ids.append(int(np.argmax(nearest)))
    centers = features[center_ids].copy()

    labels = np.zeros(len(features), dtype=np.int32)
    for _ in range(20):
        dist = ((features[:, None, :] - centers[None, :, :]) ** 2).sum(axis=2)
        new_labels = dist.argmin(axis=1)
        if np.array_equal(new_labels, labels):
            labels = new_labels
            break
        labels = new_labels
        for c in range(k):
            pts = features[labels == c]
            if len(pts):
                centers[c] = pts.mean(axis=0)
    return labels, centers


def _assign_teams(tracks):
    ids = []
    features = []
    for tid, track in tracks.items():
        colors = track.get("colors") or []
        if len(track.get("positions") or []) < 2 or len(colors) < 2:
            continue
        ids.append(tid)
        features.append(np.median(np.vstack(colors), axis=0))
    assignments = {tid: None for tid in tracks}
    if len(features) < 2:
        return assignments

    data = np.asarray(features, dtype=np.float32)
    k = 3 if len(data) >= 9 else 2
    labels, _ = _kmeans(data, k)
    counts = Counter(labels.tolist())
    team_clusters = [c for c, _ in counts.most_common(2)]
    cluster_to_team = {c: i for i, c in enumerate(team_clusters)}

    for tid, label in zip(ids, labels.tolist()):
        assignments[tid] = cluster_to_team.get(label)
    return assignments


def _svg_pitch(path: Path, tracks, team_assignments, team_filter=None, title="二维追踪图"):
    width, height = 1000, 640
    pitch = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="1000" height="640" fill="#174f36"/>',
        '<g fill="none" stroke="#f3f0e6" stroke-width="3" opacity=".88">',
        '<rect x="28" y="28" width="944" height="584"/>',
        '<line x1="500" y1="28" x2="500" y2="612"/>',
        '<circle cx="500" cy="320" r="88"/>',
        '<rect x="28" y="175" width="155" height="290"/>',
        '<rect x="817" y="175" width="155" height="290"/>',
        '</g>',
        f'<text x="34" y="55" fill="#f3f0e6" font-family="Arial,sans-serif" font-size="22" font-weight="700">{title}</text>',
    ]

    colors = {0: "#45a8ff", 1: "#ff5a73", None: "#d8b66b"}
    for tid, track in tracks.items():
        team = team_assignments.get(tid)
        if team_filter is not None and team != team_filter:
            continue
        positions = track.get("positions") or []
        if len(positions) < 2:
            continue
        pts = []
        for _, x, y in positions:
            px = 28 + float(x) * 944
            py = 28 + float(y) * 584
            pts.append(f"{px:.1f},{py:.1f}")
        color = colors.get(team, colors[None])
        pitch.append(
            f'<polyline points="{" ".join(pts)}" fill="none" stroke="{color}" stroke-width="3" opacity=".45"/>'
        )
        _, lx, ly = positions[-1]
        px = 28 + float(lx) * 944
        py = 28 + float(ly) * 584
        pitch.append(f'<circle cx="{px:.1f}" cy="{py:.1f}" r="8" fill="{color}"/>')
        pitch.append(
            f'<text x="{px + 11:.1f}" y="{py + 5:.1f}" fill="#fff" font-family="Arial,sans-serif" font-size="14">{tid}</text>'
        )

    pitch.append("</svg>")
    path.write_text("".join(pitch), encoding="utf-8")


def _svg_heatmap(path: Path, tracks, team_assignments, team, title):
    cols, rows = 20, 12
    grid = np.zeros((rows, cols), dtype=np.float32)
    for tid, track in tracks.items():
        if team_assignments.get(tid) != team:
            continue
        for _, x, y in track.get("positions") or []:
            cx = min(cols - 1, max(0, int(float(x) * cols)))
            cy = min(rows - 1, max(0, int(float(y) * rows)))
            grid[cy, cx] += 1.0
    if grid.max() > 0:
        grid /= grid.max()

    width, height = 1000, 640
    cell_w = 944 / cols
    cell_h = 584 / rows
    color = "#45a8ff" if team == 0 else "#ff5a73"
    svg = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="1000" height="640" fill="#174f36"/>',
        '<g fill="none" stroke="#f3f0e6" stroke-width="3" opacity=".86">',
        '<rect x="28" y="28" width="944" height="584"/>',
        '<line x1="500" y1="28" x2="500" y2="612"/>',
        '<circle cx="500" cy="320" r="88"/>',
        '<rect x="28" y="175" width="155" height="290"/>',
        '<rect x="817" y="175" width="155" height="290"/>',
        '</g>',
        f'<text x="34" y="55" fill="#f3f0e6" font-family="Arial,sans-serif" font-size="22" font-weight="700">{title}</text>',
    ]
    for y in range(rows):
        for x in range(cols):
            value = float(grid[y, x])
            if value <= 0.03:
                continue
            opacity = 0.10 + value * 0.72
            rx = 28 + x * cell_w
            ry = 28 + y * cell_h
            svg.append(
                f'<rect x="{rx:.1f}" y="{ry:.1f}" width="{cell_w + 1:.1f}" height="{cell_h + 1:.1f}" fill="{color}" opacity="{opacity:.3f}"/>'
            )
    svg.append("</svg>")
    path.write_text("".join(svg), encoding="utf-8")


def _update(job_id, **changes):
    with _jobs_lock:
        job = _jobs.get(job_id)
        if not job:
            return
        job.update(changes)
        job["updated_at"] = time.time()


def _run_job(job_id, video_path: Path, workdir: Path, heavy_slot: Lock, home_team: str, away_team: str, match_format: str):
    proc = None
    try:
        _update(job_id, status="running", progress=3, message="正在加载足球 AI 模型")
        with heavy_slot:
            session = _get_session()
            del session

            ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
            vf = (
                f"fps={ANALYSIS_FPS},"
                f"scale={_input_w}:{_input_h}:force_original_aspect_ratio=decrease,"
                f"pad={_input_w}:{_input_h}:(ow-iw)/2:(oh-ih)/2"
            )
            cmd = [
                ffmpeg,
                "-v", "error",
                "-t", str(MAX_SECONDS),
                "-i", str(video_path),
                "-vf", vf,
                "-f", "rawvideo",
                "-pix_fmt", "rgb24",
                "pipe:1",
            ]
            proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            frame_size = _input_w * _input_h * 3

            tracks = {}
            next_id = 1
            frame_no = 0
            possession_track_ids = []
            possession_weights = []
            ball_track = None
            last_possessor = None
            ball_seen = 0
            ball_tracked = 0
            person_samples = 0

            while True:
                raw = proc.stdout.read(frame_size)
                if not raw or len(raw) < frame_size:
                    break
                frame = np.frombuffer(raw, dtype=np.uint8).reshape((_input_h, _input_w, 3))
                people, balls = _detect(frame)
                person_samples += len(people)

                for person in people:
                    color = _jersey_rgb(frame, person["box"])
                    person["jersey_rgb"] = color

                assignments, next_id = _match_tracks(tracks, people, frame_no, next_id)
                for idx, person in enumerate(people):
                    tid = assignments[idx]
                    track = tracks.setdefault(
                        tid,
                        {
                            "last_frame": frame_no,
                            "last_pos": (person["cx"], person["cy"]),
                            "positions": [],
                            "colors": [],
                        },
                    )
                    track["last_frame"] = frame_no
                    track["last_pos"] = (person["cx"], person["cy"])
                    track["positions"].append((frame_no, person["cx"], person["cy"]))
                    color = person.get("jersey_rgb")
                    if color is not None:
                        track["colors"].append(color)

                ball_track, ball_state = _update_ball_track(ball_track, balls, frame_no)
                if ball_state is not None:
                    ball_tracked += 1
                    if ball_state["observed"]:
                        ball_seen += 1

                if ball_state is not None and people:
                    nearest = None
                    nearest_d = 999.0
                    for idx, person in enumerate(people):
                        d = math.hypot(person["cx"] - ball_state["cx"], person["cy"] - ball_state["cy"])
                        if d < nearest_d:
                            nearest_d = d
                            nearest = assignments[idx]

                    if nearest is not None and nearest_d <= 0.16:
                        weight = 1.0 if ball_state["observed"] else 0.35
                        if last_possessor is not None and nearest != last_possessor and ball_state["observed"]:
                            weight = 0.65
                        possession_track_ids.append(nearest)
                        possession_weights.append(weight)
                        last_possessor = nearest

                frame_no += 1
                max_frames = max(1, int(MAX_SECONDS * ANALYSIS_FPS))
                pct = min(88, 8 + int(frame_no / max_frames * 80))
                if frame_no % 3 == 0:
                    _update(
                        job_id,
                        progress=pct,
                        message=f"AI 正在分析比赛 · 已处理 {frame_no} 个采样画面",
                    )

            if proc.stdout:
                proc.stdout.close()
            stderr = proc.stderr.read().decode("utf-8", "ignore") if proc.stderr else ""
            return_code = proc.wait(timeout=10)
            if return_code not in (0, None) and frame_no == 0:
                raise RuntimeError("视频读取失败：" + stderr[-240:])
            if frame_no == 0:
                raise RuntimeError("没有读取到可分析的比赛画面。")

            _update(job_id, progress=90, message="正在自动区分两支球队")
            team_assignments = _assign_teams(tracks)

            stable_ids = _stable_track_ids(tracks, team_assignments, frame_no, match_format)
            stable_tracks = {tid: track for tid, track in tracks.items() if tid in stable_ids}

            team_counts = Counter()
            for tid in stable_ids:
                team = team_assignments.get(tid)
                if team in (0, 1):
                    team_counts[team] += 1

            possession_counts = {0: 0.0, 1: 0.0}
            for tid, weight in zip(possession_track_ids, possession_weights):
                team = team_assignments.get(tid)
                if team in (0, 1):
                    possession_counts[team] += float(weight)

            poss_total = possession_counts[0] + possession_counts[1]
            possession_available = ball_seen >= POSSESSION_MIN_SAMPLES and poss_total > 0
            if possession_available:
                home_poss = round(possession_counts[0] / poss_total * 100, 1)
                away_poss = round(100.0 - home_poss, 1)
            else:
                home_poss = None
                away_poss = None
            possession_confidence = min(100, int(round(ball_seen / max(POSSESSION_MIN_SAMPLES * 2, 1) * 100)))

            _update(job_id, progress=94, message="正在生成稳定追踪图和活动热区")
            tracking_svg = workdir / "tracking-map.svg"
            home_svg = workdir / "home-heatmap.svg"
            away_svg = workdir / "away-heatmap.svg"
            _svg_pitch(tracking_svg, stable_tracks, team_assignments, title="SAGI · 稳定球员追踪")
            _svg_heatmap(home_svg, stable_tracks, team_assignments, 0, f"{home_team} · 活动热区")
            _svg_heatmap(away_svg, stable_tracks, team_assignments, 1, f"{away_team} · 活动热区")

            public_tracks = []
            for tid, track in sorted(stable_tracks.items()):
                positions = track.get("positions") or []
                public_tracks.append(
                    {
                        "track_id": tid,
                        "team": team_assignments.get(tid),
                        "visible_samples": len(positions),
                    }
                )

            result = {
                "version": MATCH_VERSION,
                "mode": "SAGI Tracking Core",
                "match": {"home_team": home_team, "away_team": away_team},
                "video": {
                    "sampled_frames": frame_no,
                    "analysis_fps": ANALYSIS_FPS,
                    "max_seconds": MAX_SECONDS,
                    "ball_seen_samples": ball_seen,
                    "ball_tracked_samples": ball_tracked,
                    "person_detection_samples": person_samples,
                    "raw_track_count": len(tracks),
                    "stable_track_count": len(stable_tracks),
                },
                "teams": {
                    "home": {
                        "name": home_team,
                        "tracked_players": int(team_counts[0]),
                        "possession_percent": home_poss,
                        "possession_available": possession_available,
                        "heatmap": "home-heatmap.svg",
                    },
                    "away": {
                        "name": away_team,
                        "tracked_players": int(team_counts[1]),
                        "possession_percent": away_poss,
                        "possession_available": possession_available,
                        "heatmap": "away-heatmap.svg",
                    },
                },
                "possession": {
                    "available": possession_available,
                    "observed_ball_samples": ball_seen,
                    "tracked_ball_samples": ball_tracked,
                    "minimum_samples": POSSESSION_MIN_SAMPLES,
                    "confidence_percent": possession_confidence,
                },
                "tracking": {
                    "raw_track_count": len(tracks),
                    "stable_track_count": len(stable_tracks),
                    "max_age_frames": TRACK_MAX_AGE,
                    "expected_players_per_team": _expected_players(match_format),
                },
                "tracks": public_tracks,
                "tracking_map": "tracking-map.svg",
                "limitations": [
                    "V1.1.2 使用位置预测与球衣颜色联合追踪，显著减少短时遮挡造成的新 ID。",
                    "报告只统计持续出现的稳定轨迹，并按比赛制式限制单队场上追踪数量。",
                    "足球短暂消失时最多续接数个采样帧，但高速小球仍可能漏检。",
                    "足球观测样本不足时不再输出误导性的控球率百分比。",
                    f"当前云端版最多分析视频前 {MAX_SECONDS} 秒。",
                ],
            }

            _update(
                job_id,
                status="completed",
                progress=100,
                message="比赛分析完成",
                result=result,
            )
    except Exception as exc:
        _update(
            job_id,
            status="failed",
            progress=100,
            message=str(exc)[:400],
            error=type(exc).__name__,
        )
    finally:
        if proc and proc.poll() is None:
            try:
                proc.kill()
            except Exception:
                pass


def create_match_intelligence_blueprint(heavy_slot: Lock, allowed_origin: str):
    bp = Blueprint("match_intelligence_lite", __name__)

    def _origin_ok():
        origin = (request.headers.get("Origin") or "").rstrip("/")
        return not origin or origin == allowed_origin.rstrip("/")

    @bp.get("/api/match-intelligence/health")
    def match_health():
        return jsonify(
            {
                "ok": True,
                "service": "SAGI 比赛智能分析",
                "version": MATCH_VERSION,
                "engine": "YOLO11 ONNX Runtime + SAGI Tracking Core",
                "analysisFps": ANALYSIS_FPS,
                "maxSeconds": MAX_SECONDS,
                "maxUploadMB": MAX_UPLOAD_MB,
            }
        )

    @bp.post("/api/match-intelligence/jobs")
    def create_job():
        if not _origin_ok():
            return jsonify({"error": "不允许的来源。"}), 403

        if request.content_length and request.content_length > MAX_UPLOAD_MB * 1024 * 1024:
            return jsonify({"error": f"视频超过 {MAX_UPLOAD_MB}MB 测试限制。"}), 413

        upload = request.files.get("video")
        if upload is None or not upload.filename:
            return jsonify({"error": "请选择比赛视频。"}), 400

        suffix = Path(upload.filename).suffix.lower()
        if suffix not in (".mp4", ".mov", ".m4v", ".mkv", ".avi", ".webm"):
            return jsonify({"error": "暂不支持这个视频格式。"}), 400

        home_team = str(request.form.get("home_team") or "主队").strip()[:60] or "主队"
        away_team = str(request.form.get("away_team") or "客队").strip()[:60] or "客队"
        match_format = str(request.form.get("match_format") or "7v7").strip()[:16]

        job_id = uuid.uuid4().hex[:12]
        workdir = Path(tempfile.mkdtemp(prefix=f"sagi_match_{job_id}_"))
        source = workdir / ("input" + suffix)
        upload.save(str(source))
        if source.stat().st_size > MAX_UPLOAD_MB * 1024 * 1024:
            shutil.rmtree(workdir, ignore_errors=True)
            return jsonify({"error": f"视频超过 {MAX_UPLOAD_MB}MB 测试限制。"}), 413

        with _jobs_lock:
            _jobs[job_id] = {
                "job_id": job_id,
                "status": "queued",
                "progress": 0,
                "message": "等待 AI 分析",
                "home_team": home_team,
                "away_team": away_team,
                "match_format": match_format,
                "workdir": str(workdir),
                "created_at": time.time(),
                "updated_at": time.time(),
            }

        Thread(
            target=_run_job,
            args=(job_id, source, workdir, heavy_slot, home_team, away_team, match_format),
            daemon=True,
        ).start()
        return jsonify({"job_id": job_id, "status": "queued"}), 202

    @bp.get("/api/match-intelligence/jobs/<job_id>")
    def get_job(job_id):
        with _jobs_lock:
            job = _jobs.get(job_id)
            if not job:
                return jsonify({"error": "没有找到这个分析任务。"}), 404
            public = {k: v for k, v in job.items() if k not in ("workdir",)}
        return jsonify(public)

    @bp.get("/api/match-intelligence/jobs/<job_id>/artifacts/<filename>")
    def get_artifact(job_id, filename):
        safe = Path(filename).name
        if safe != filename:
            return jsonify({"error": "文件名无效。"}), 400
        with _jobs_lock:
            job = _jobs.get(job_id)
            if not job:
                return jsonify({"error": "没有找到这个分析任务。"}), 404
            workdir = Path(job["workdir"])
        path = workdir / safe
        if not path.exists() or not path.is_file():
            return jsonify({"error": "分析文件还没有生成。"}), 404
        return send_file(str(path), mimetype="image/svg+xml", conditional=True)

    return bp
