#!/usr/bin/env python3
import json
import sys


def event_start(ev):
    if ev.get("type") in ("pass", "shot"):
        return float(ev.get("release", ev.get("t", 0)))
    return float(ev.get("t", 0))


def main(path):
    with open(path, "r", encoding="utf-8") as f:
        cfg = json.load(f)

    events = cfg.get("events", [])
    chain = []
    errors = []
    warnings = []

    for i, ev in enumerate(events):
        if ev.get("type") != "pass":
            continue

        receiver = ev.get("to")
        arrive = float(ev.get("arrive", 0))
        next_ev = None

        for candidate in events[i + 1:]:
            typ = candidate.get("type")
            if typ == "pass" and candidate.get("from") == receiver:
                next_ev = candidate
                break
            if typ == "dribble" and candidate.get("player") == receiver:
                next_ev = candidate
                break
            if typ == "shot" and candidate.get("from") == receiver:
                next_ev = candidate
                break

        item = {
            "receiver": receiver,
            "arrive": arrive,
            "next_type": None,
            "next_start": None,
            "gap_sec": None,
        }

        if next_ev is None:
            warnings.append(f"{receiver} receives at {arrive:.2f}s with no next action")
        else:
            ns = event_start(next_ev)
            gap = ns - arrive
            item.update({
                "next_type": next_ev.get("type"),
                "next_start": ns,
                "gap_sec": round(gap, 3),
            })
            if gap < 0:
                errors.append(
                    f"{receiver} next action begins before reception completes ({gap:.2f}s)"
                )
            if gap > 2.5:
                warnings.append(
                    f"{receiver} holds for {gap:.2f}s before next action; check dead time"
                )

        chain.append(item)

    report = {
        "version": cfg.get("version"),
        "valid": not errors,
        "receive_action_chain": chain,
        "errors": errors,
        "warnings": warnings,
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))
    raise SystemExit(0 if not errors else 2)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: audit_action_chain.py preset.json")
    main(sys.argv[1])
