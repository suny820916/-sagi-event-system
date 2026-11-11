from __future__ import annotations

import json
import math
import subprocess
from collections import Counter, defaultdict
from pathlib import Path
from typing import Callable

import cv2
import numpy as np

from .config import settings

ProgressCallback = Callable[[float, str], None]


def _jersey_hsv(frame: np.ndarray, box: tuple[int, int, int, int]) -> np.ndarray | None:
    """Sample the central upper torso and return a robust HSV colour feature."""
    x1, y1, x2, y2 = box
    width = max(1, x2 - x1)
    height = max(1, y2 - y1)

    cx1 = int(x1 + width * 0.25)
    cx2 = int(x1 + width * 0.75)
    cy1 = int(y1 + height * 0.18)
    cy2 = int(y1 + height * 0.52)

    crop = frame[max(0, cy1):max(0, cy2), max(0, cx1):max(0, cx2)]
    if crop.size == 0:
        return None

    hsv = cv2.cvtColor(crop, cv2.COLOR_BGR2HSV)
    pixels = hsv.reshape(-1, 3)

    # Remove very dark and near-white pixels; they often belong to shadows/numbers.
    mask = (pixels[:, 2] > 45) & ~((pixels[:, 1] < 30) & (pixels[:, 2] > 205))
    filtered = pixels[mask]
    if len(filtered) < 20:
        filtered = pixels
    if len(filtered) == 0:
        return None

    return np.median(filtered, axis=0).astype(np.float32)


def _classify_tracks(
    samples: dict[int, list[np.ndarray]],
) -> tuple[dict[int, int | None], dict[str, list[float]]]:
    """Cluster persistent tracks by jersey colour.

    The two largest colour clusters are treated as teams. A third cluster, when
    enough tracks exist, is intentionally left unassigned (often referees or
    goalkeeper kit).
    """
    features: list[np.ndarray] = []
    ids: list[int] = []

    for track_id, values in samples.items():
        if len(values) < 2:
            continue
        features.append(np.median(np.vstack(values), axis=0))
        ids.append(track_id)

    assignments: dict[int, int | None] = {track_id: None for track_id in samples}
    if len(features) < 2:
        return assignments, {}

    data = np.float32(np.vstack(features))
    k = 3 if len(features) >= 10 else 2

    criteria = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 50, 0.2)
    _compactness, labels, centers = cv2.kmeans(
        data,
        k,
        None,
        criteria,
        8,
        cv2.KMEANS_PP_CENTERS,
    )

    raw_labels = labels.reshape(-1).tolist()
    counts = Counter(raw_labels)
    team_clusters = [cluster for cluster, _ in counts.most_common(2)]
    cluster_to_team = {cluster: idx for idx, cluster in enumerate(team_clusters)}

    for track_id, cluster in zip(ids, raw_labels):
        assignments[track_id] = cluster_to_team.get(cluster)

    centroids = {
        f"team_{team}": centers[cluster].astype(float).tolist()
        for cluster, team in cluster_to_team.items()
    }
    return assignments, centroids


def _pitch_canvas(width: int = 1000, height: int = 640) -> np.ndarray:
    canvas = np.full((height, width, 3), (32, 91, 58), dtype=np.uint8)
    white = (232, 239, 235)
    t = max(2, width // 400)
    cv2.rectangle(canvas, (20, 20), (width - 20, height - 20), white, t)
    cv2.line(canvas, (width // 2, 20), (width // 2, height - 20), white, t)
    cv2.circle(canvas, (width // 2, height // 2), int(height * 0.14), white, t)

    box_w, box_h = int(width * 0.16), int(height * 0.44)
    y1 = (height - box_h) // 2
    y2 = y1 + box_h
    cv2.rectangle(canvas, (20, y1), (20 + box_w, y2), white, t)
    cv2.rectangle(canvas, (width - 20 - box_w, y1), (width - 20, y2), white, t)
    return canvas


def _write_heatmap(
    positions: list[tuple[float, float]],
    output_path: Path,
) -> None:
    """Create a pitch-shaped screen-space heatmap.

    V1 uses normalized video coordinates. V1.1 will replace this with calibrated
    pitch coordinates using homography.
    """
    pitch = _pitch_canvas()
    h, w = pitch.shape[:2]
    density = np.zeros((h, w), dtype=np.float32)

    for x, y in positions:
        px = int(np.clip(x, 0.0, 1.0) * (w - 1))
        py = int(np.clip(y, 0.0, 1.0) * (h - 1))
        cv2.circle(density, (px, py), max(10, w // 70), 1.0, -1)

    if positions:
        density = cv2.GaussianBlur(density, (0, 0), sigmaX=max(12, w / 45))
        if density.max() > 0:
            density = density / density.max()

    heat = np.uint8(np.clip(density * 255, 0, 255))
    coloured = cv2.applyColorMap(heat, cv2.COLORMAP_TURBO)
    alpha = (density * 0.72)[:, :, None]
    composed = (pitch * (1 - alpha) + coloured * alpha).astype(np.uint8)
    cv2.imwrite(str(output_path), composed)


def analyze_match(
    video_path: Path,
    output_dir: Path,
    home_team: str,
    away_team: str,
    progress: ProgressCallback | None = None,
) -> dict:
    from ultralytics import YOLO

    output_dir.mkdir(parents=True, exist_ok=True)
    model = YOLO(settings.model)

    cap = cv2.VideoCapture(str(video_path))
    if not cap.isOpened():
        raise RuntimeError("Could not open uploaded video.")

    fps = float(cap.get(cv2.CAP_PROP_FPS) or 25.0)
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT) or 0)
    frame_width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH) or 1280)
    frame_height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT) or 720)
    sample_every = max(1, int(round(fps / max(settings.analysis_fps, 0.5))))
    preview_fps = max(1.0, fps / sample_every)

    raw_preview_path = output_dir / "analysis-preview-raw.mp4"
    preview_path = output_dir / "analysis-preview.mp4"
    writer = cv2.VideoWriter(
        str(raw_preview_path),
        cv2.VideoWriter_fourcc(*"mp4v"),
        preview_fps,
        (frame_width, frame_height),
    )

    if not writer.isOpened():
        cap.release()
        raise RuntimeError("Could not create analysis preview video.")

    track_colours: dict[int, list[np.ndarray]] = defaultdict(list)
    track_positions: dict[int, list[tuple[float, float]]] = defaultdict(list)
    visible_samples: Counter[int] = Counter()
    possession_candidates: list[int] = []
    sampled_frames = 0
    ball_seen_frames = 0

    frame_index = 0
    while True:
        ok, frame = cap.read()
        if not ok:
            break

        if frame_index % sample_every != 0:
            frame_index += 1
            continue

        sampled_frames += 1
        result = model.track(
            frame,
            persist=True,
            tracker="bytetrack.yaml",
            classes=[0, 32],  # COCO: person, sports ball
            conf=settings.conf,
            device=settings.device,
            verbose=False,
        )[0]

        people: list[tuple[int, tuple[int, int, int, int], tuple[float, float]]] = []
        balls: list[tuple[float, float, float]] = []

        if result.boxes is not None:
            for box in result.boxes:
                cls_id = int(box.cls.item())
                conf = float(box.conf.item())
                xyxy = box.xyxy[0].cpu().numpy().astype(int).tolist()
                x1, y1, x2, y2 = xyxy

                if cls_id == 0 and box.id is not None:
                    track_id = int(box.id.item())
                    foot_x = ((x1 + x2) / 2.0) / max(1, frame_width)
                    foot_y = y2 / max(1, frame_height)
                    people.append((track_id, (x1, y1, x2, y2), (foot_x, foot_y)))
                    track_positions[track_id].append((foot_x, foot_y))
                    visible_samples[track_id] += 1

                    colour = _jersey_hsv(frame, (x1, y1, x2, y2))
                    if colour is not None:
                        track_colours[track_id].append(colour)

                    cv2.rectangle(frame, (x1, y1), (x2, y2), (235, 235, 235), 2)
                    cv2.putText(
                        frame,
                        f"ID {track_id}",
                        (x1, max(20, y1 - 8)),
                        cv2.FONT_HERSHEY_SIMPLEX,
                        0.6,
                        (255, 255, 255),
                        2,
                        cv2.LINE_AA,
                    )

                elif cls_id == 32:
                    cx = (x1 + x2) / 2.0
                    cy = (y1 + y2) / 2.0
                    balls.append((cx, cy, conf))
                    cv2.circle(frame, (int(cx), int(cy)), 8, (0, 220, 255), 2)

        if balls and people:
            ball_seen_frames += 1
            bx, by, _ = max(balls, key=lambda item: item[2])
            nearest_id = None
            nearest_distance = math.inf
            for track_id, (_x1, _y1, _x2, _y2), (nx, ny) in people:
                px = nx * frame_width
                py = ny * frame_height
                distance = math.hypot(px - bx, py - by)
                if distance < nearest_distance:
                    nearest_distance = distance
                    nearest_id = track_id

            possession_radius = max(frame_width, frame_height) * 0.12
            if nearest_id is not None and nearest_distance <= possession_radius:
                possession_candidates.append(nearest_id)

        cv2.putText(
            frame,
            "SAGI MATCH INTELLIGENCE V1.0",
            (24, 42),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.85,
            (255, 255, 255),
            2,
            cv2.LINE_AA,
        )
        writer.write(frame)

        if progress and sampled_frames % 10 == 0:
            if total_frames > 0:
                pct = min(95.0, 5.0 + (frame_index / total_frames) * 90.0)
            else:
                pct = 50.0
            progress(pct, f"AI analysing frame {frame_index:,}")

        frame_index += 1

    cap.release()
    writer.release()

    if progress:
        progress(95.0, "Optimising mobile preview")

    try:
        subprocess.run(
            [
                "ffmpeg",
                "-y",
                "-i",
                str(raw_preview_path),
                "-an",
                "-c:v",
                "libx264",
                "-preset",
                "veryfast",
                "-crf",
                "24",
                "-pix_fmt",
                "yuv420p",
                "-movflags",
                "+faststart",
                str(preview_path),
            ],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        raw_preview_path.unlink(missing_ok=True)
    except (FileNotFoundError, subprocess.CalledProcessError):
        raw_preview_path.replace(preview_path)

    track_team, centroids = _classify_tracks(track_colours)

    team_positions: dict[int, list[tuple[float, float]]] = {0: [], 1: []}
    for track_id, positions in track_positions.items():
        team = track_team.get(track_id)
        if team in (0, 1):
            team_positions[team].extend(positions)

    possession_counter = Counter()
    for track_id in possession_candidates:
        team = track_team.get(track_id)
        if team in (0, 1):
            possession_counter[team] += 1

    possession_total = possession_counter[0] + possession_counter[1]
    home_possession = (
        round(possession_counter[0] / possession_total * 100.0, 1)
        if possession_total
        else 0.0
    )
    away_possession = round(100.0 - home_possession, 1) if possession_total else 0.0

    _write_heatmap(team_positions[0], output_dir / "home-heatmap.png")
    _write_heatmap(team_positions[1], output_dir / "away-heatmap.png")

    tracks = []
    for track_id in sorted(track_positions):
        tracks.append(
            {
                "track_id": track_id,
                "team": track_team.get(track_id),
                "visible_samples": visible_samples[track_id],
                "sampled_positions": len(track_positions[track_id]),
            }
        )

    result_payload = {
        "version": "1.0.0-alpha",
        "match": {
            "home_team": home_team,
            "away_team": away_team,
        },
        "video": {
            "fps": fps,
            "frames": total_frames,
            "sampled_frames": sampled_frames,
            "analysis_fps": settings.analysis_fps,
            "ball_seen_samples": ball_seen_frames,
        },
        "teams": {
            "home": {
                "name": home_team,
                "cluster": 0,
                "tracked_players": sum(1 for t in tracks if t["team"] == 0),
                "possession_percent": home_possession,
                "heatmap": "home-heatmap.png",
            },
            "away": {
                "name": away_team,
                "cluster": 1,
                "tracked_players": sum(1 for t in tracks if t["team"] == 1),
                "possession_percent": away_possession,
                "heatmap": "away-heatmap.png",
            },
        },
        "tracks": tracks,
        "team_colour_centroids_hsv": centroids,
        "artifacts": [
            "analysis-preview.mp4",
            "home-heatmap.png",
            "away-heatmap.png",
            "result.json",
        ],
        "limitations": [
            "V1 heatmaps use normalized screen coordinates, not calibrated pitch coordinates.",
            "Home/away colour clusters may need manual swapping.",
            "Player identity is track-based and may fragment after occlusion.",
            "Possession is an estimate based on ball proximity.",
        ],
    }

    (output_dir / "result.json").write_text(
        json.dumps(result_payload, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    if progress:
        progress(100.0, "Analysis complete")

    return result_payload
