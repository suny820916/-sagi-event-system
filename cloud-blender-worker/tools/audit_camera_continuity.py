#!/usr/bin/env python3
import json
import sys


def predicted_pos(cfg, name, t):
    x, y = map(float, cfg["players"][name]["pos"])
    for ev in cfg.get("events", []):
        if ev.get("type") not in ("player_move", "defender_shift", "dribble"):
            continue
        if ev.get("player") != name:
            continue
        t0 = float(ev["t"])
        dur = max(1e-6, float(ev["duration"]))
        t1 = t0 + dur
        tx, ty = map(float, ev["to"])
        if t < t0:
            break
        if t >= t1:
            x, y = tx, ty
            continue
        a = max(0.0, min(1.0, (t - t0) / dur))
        return x + (tx - x) * a, y + (ty - y) * a
    return x, y


def main(path):
    with open(path, "r", encoding="utf-8") as f:
        cfg = json.load(f)

    ccfg = cfg.get("camera_continuity", {})
    max_back = float(ccfg.get("max_backward_target_m", 1.5))
    preserve = bool(ccfg.get("preserve_forward_progression", False))

    cameras = [e for e in cfg.get("events", []) if e.get("type") == "relation_camera"]
    rows = []
    errors = []
    prev_y = None

    for idx, ev in enumerate(cameras):
        focus_t = float(ev.get("focus_t", ev["t"]))
        pts = [predicted_pos(cfg, n, focus_t) for n in ev["subjects"]]
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        cx = (min(xs) + max(xs)) * 0.5
        cy_raw = (min(ys) + max(ys)) * 0.5
        cy = cy_raw

        if prev_y is not None and preserve:
            min_allowed = prev_y - max_back
            if cy < min_allowed:
                cy = min_allowed

        backward = 0.0 if prev_y is None else max(0.0, prev_y - cy)
        if backward > max_back + 1e-6:
            errors.append(
                f"camera {idx} at {ev['t']}s moves backward {backward:.2f}m"
            )

        rows.append({
            "t": float(ev["t"]),
            "focus_t": focus_t,
            "target_raw": [round(cx, 2), round(cy_raw, 2)],
            "target_guarded": [round(cx, 2), round(cy, 2)],
            "backward_m": round(backward, 2),
            "subjects": ev["subjects"],
        })
        prev_y = cy

    report = {
        "version": cfg.get("version"),
        "valid": not errors,
        "camera_count": len(cameras),
        "max_backward_target_m": max_back,
        "rows": rows,
        "errors": errors,
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))
    raise SystemExit(0 if not errors else 2)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: audit_camera_continuity.py preset.json")
    main(sys.argv[1])
