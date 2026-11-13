#!/usr/bin/env python3
"""Build the 101-second SAGI Christmas-tree master from the four lesson segments.

This removes manual copy drift between:
00-06 intro
06-42 attack
43-76 defense
76-101 summary
"""

from __future__ import annotations

import json
from copy import deepcopy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PRESETS = ROOT / "cloud-blender-worker" / "presets"

INTRO = PRESETS / "christmas_tree_intro_00_06.json"
ATTACK = PRESETS / "christmas_tree_attack_06_42.json"
DEFENSE = PRESETS / "christmas_tree_defense_43_76.json"
SUMMARY = PRESETS / "christmas_tree_summary_76_101.json"
OUTPUT = PRESETS / "christmas_tree_full_lesson_00_101.json"


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def shift_events(events: list[dict], offset: float) -> list[dict]:
    out: list[dict] = []
    for event in events:
        ev = deepcopy(event)
        ev["t"] = round(float(ev["t"]) + offset, 3)
        if "release" in ev:
            ev["release"] = round(float(ev["release"]) + offset, 3)
        if "arrive" in ev:
            ev["arrive"] = round(float(ev["arrive"]) + offset, 3)
        out.append(ev)
    return out


def chapter_state(segment: dict, t: float) -> dict:
    return {
        "t": t,
        "type": "chapter_state",
        "visible_players": list(segment["players"].keys()),
        "positions": {
            name: deepcopy(data["pos"])
            for name, data in segment["players"].items()
        },
        "ball_owner": segment.get("ball_start_player", "PIRLO"),
    }


def merge_players(*segments: dict) -> dict:
    players: dict = {}
    for segment in segments:
        for name, data in segment["players"].items():
            players.setdefault(name, deepcopy(data))
    return players


def validate(master: dict) -> None:
    names = set(master["players"])
    duration = float(master["duration_sec"])
    last_t = -1.0

    for idx, ev in enumerate(master["events"]):
        t = float(ev["t"])
        if t < last_t:
            raise ValueError(f"events not sorted at index {idx}")
        if not (0 <= t <= duration):
            raise ValueError(f"event {idx} outside duration: {t}")
        last_t = t

        for key in ("player", "from"):
            value = ev.get(key)
            if isinstance(value, str) and value not in names:
                raise ValueError(f"event {idx}: unknown {key} {value}")

        value = ev.get("to")
        if isinstance(value, str) and value not in names:
            raise ValueError(f"event {idx}: unknown receiver {value}")

        for value in ev.get("players", []):
            if value not in names:
                raise ValueError(f"event {idx}: unknown group player {value}")

        for value in ev.get("visible_players", []):
            if value not in names:
                raise ValueError(f"event {idx}: unknown visible player {value}")

        for value in ev.get("positions", {}):
            if value not in names:
                raise ValueError(f"event {idx}: unknown chapter player {value}")

        release = ev.get("release")
        arrive = ev.get("arrive")
        if release is not None and not (t <= float(release) <= duration):
            raise ValueError(f"event {idx}: invalid release {release}")
        if arrive is not None and not (float(release) <= float(arrive) <= duration):
            raise ValueError(f"event {idx}: invalid arrive {arrive}")


def build() -> dict:
    intro = load(INTRO)
    attack = load(ATTACK)
    defense = load(DEFENSE)
    summary = load(SUMMARY)

    events = [
        chapter_state(intro, 0),
        *shift_events(intro["events"], 0),
        chapter_state(attack, 6),
        *shift_events(attack["events"], 6),
        chapter_state(defense, 43),
        *shift_events(defense["events"], 43),
        chapter_state(summary, 76),
        *shift_events(summary["events"], 76),
    ]
    events.sort(key=lambda ev: float(ev["t"]))

    master = {
        "project": "SAGI TACTICS",
        "version": "CHRISTMAS TREE 4-3-2-1 · FULL LESSON 00-101 · GENERATED MASTER",
        "fps": 24,
        "duration_sec": 101,
        "resolution": [540, 960],
        "render_engine": "BLENDER_WORKBENCH",
        "attack_direction": "full lesson",
        "ball_start_player": intro.get("ball_start_player", "PIRLO"),
        "timeline_offset_sec": 0,
        "timeline_end_sec": 101,
        "palette": deepcopy(intro["palette"]),
        "players": merge_players(intro, attack, defense, summary),
        "lesson_markers": [
            {
                "id": "intro",
                "label": "SAGI intro and Christmas-tree setup",
                "local_start": 0,
                "local_end": 6,
                "global_start": 0,
                "global_end": 6,
            },
            *deepcopy(attack.get("lesson_markers", [])),
            *deepcopy(defense.get("lesson_markers", [])),
            *deepcopy(summary.get("lesson_markers", [])),
        ],
        "chapters": [
            {"id": "intro", "local_start": 0, "local_end": 6, "global_start": 0, "global_end": 6},
            {"id": "attack", "local_start": 6, "local_end": 42, "global_start": 6, "global_end": 42},
            {"id": "defense", "local_start": 43, "local_end": 76, "global_start": 43, "global_end": 76},
            {"id": "summary", "local_start": 76, "local_end": 101, "global_start": 76, "global_end": 101},
        ],
        "source_versions": {
            "intro": intro.get("version"),
            "attack": attack.get("version"),
            "defense": defense.get("version"),
            "summary": summary.get("version"),
        },
        "events": events,
        "preview_mode": True,
    }
    validate(master)
    return master


if __name__ == "__main__":
    master = build()
    OUTPUT.write_text(
        json.dumps(master, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(
        "SAGI_MASTER_BUILT",
        f"players={len(master['players'])}",
        f"events={len(master['events'])}",
        f"duration={master['duration_sec']}",
        OUTPUT,
    )
