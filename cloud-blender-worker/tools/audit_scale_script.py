#!/usr/bin/env python3
import json, sys

EXPECTED = {
    "BUILD": {"STRUCTURE"},
    "STRETCH": {"WIDE_STRUCTURE"},
    "BETWEEN_LINES": {"RELATION"},
    "OVERLAP": {"RELATION"},
    "SHIFT_AND_SWITCH": {"WIDE_STRUCTURE"},
    "COMPLETE": {"RESULT_RELATION"},
}

def main(path):
    with open(path, "r", encoding="utf-8") as f:
        cfg = json.load(f)

    cams = [e for e in cfg.get("events", []) if e.get("type") == "relation_camera"]
    errors, rows = [], []

    for e in cams:
        phase = e.get("phase_name")
        scale = e.get("shot_scale")
        scope = e.get("field_scope")
        subjects = e.get("subjects", [])
        allowed = EXPECTED.get(phase)
        if allowed and scale not in allowed:
            errors.append(f"{phase}: expected {sorted(allowed)}, got {scale}")
        if not scope:
            errors.append(f"{phase}: missing field_scope")
        if scale in ("RELATION", "RESULT_RELATION") and len(subjects) > 5:
            errors.append(f"{phase}: local relation uses {len(subjects)} subjects; likely too broad")
        rows.append({
            "phase": phase,
            "shot_scale": scale,
            "field_scope": scope,
            "subjects": len(subjects),
        })

    sequence = [r["shot_scale"] for r in rows]
    expected_sequence = [
        "STRUCTURE",
        "WIDE_STRUCTURE",
        "RELATION",
        "RELATION",
        "WIDE_STRUCTURE",
        "RESULT_RELATION",
    ]
    if sequence != expected_sequence:
        errors.append(f"scale sequence changed: {sequence}")

    out = {
        "version": cfg.get("version"),
        "valid": not errors,
        "principle": "camera and visible field extent must follow the tactical question",
        "rows": rows,
        "errors": errors,
    }
    print(json.dumps(out, ensure_ascii=False, indent=2))
    raise SystemExit(0 if not errors else 2)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: audit_scale_script.py preset.json")
    main(sys.argv[1])
