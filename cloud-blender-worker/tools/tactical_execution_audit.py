#!/usr/bin/env python3
import json, sys
from pathlib import Path

NON_TACTICAL={"camera","camera_dna","focus","space"}

def start(e):
    return float(e.get("t", e.get("release", 0.0)))

def end(e):
    t=e.get("type")
    if t in ("pass","shot"):
        return float(e.get("arrive", e.get("release", start(e))))
    if t in ("player_move","defender_shift","dribble","space"):
        return start(e)+float(e.get("duration",0.0))
    return start(e)

def audit(cfg):
    events=cfg.get("events",[])
    duration=float(cfg.get("duration_sec",0.0))
    holder=cfg.get("initial_ball_holder")
    errors=[]; warnings=[]; chain=[]

    # possession continuity
    for i,e in enumerate(events):
        t=e.get("type")
        if t=="pass":
            if holder and e.get("from")!=holder:
                errors.append(f"possession break at event {i}: expected {holder}, got {e.get('from')}")
            holder=e.get("to")
            chain.append(f"{e.get('from')}->{e.get('to')}")
        elif t=="dribble":
            if holder and e.get("player")!=holder:
                errors.append(f"dribble break at event {i}: holder={holder}, player={e.get('player')}")
            chain.append(f"{e.get('player')}->DRIBBLE")
        elif t=="shot":
            if holder and e.get("from")!=holder:
                errors.append(f"shot break at event {i}: holder={holder}, shooter={e.get('from')}")
            chain.append(f"{e.get('from')}->TARGET")

    tactical=[e for e in events if e.get("type") not in NON_TACTICAL]
    intervals=sorted((start(e),end(e),e.get("type")) for e in tactical)
    gaps=[]
    cursor=0.0
    for s,e,t in intervals:
        if s>cursor:
            gaps.append((round(cursor,2),round(s,2),round(s-cursor,2)))
        cursor=max(cursor,e)
    if duration>cursor:
        gaps.append((round(cursor,2),round(duration,2),round(duration-cursor,2)))

    # only flag interior dead time; final hold has its own range
    for g0,g1,gd in gaps:
        if g1 < duration-0.01 and gd>1.2:
            warnings.append(f"interior dead time {gd:.2f}s from {g0:.2f} to {g1:.2f}")

    final_hold=max(0.0,duration-max([end(e) for e in tactical] or [0.0]))
    if final_hold<0.6:
        warnings.append(f"final hold too short: {final_hold:.2f}s")
    if final_hold>1.2:
        warnings.append(f"final hold too long: {final_hold:.2f}s")

    # camera restraint
    cams=[e for e in events if e.get("type") in ("camera","camera_dna")]
    phases=cfg.get("execution_phases",[])
    phase_report=[]
    for p in phases:
        p0=float(p["from"]); p1=float(p["to"])
        pe=[e for e in events if start(e)>=p0 and start(e)<p1]
        cam_count=sum(e.get("type") in ("camera","camera_dna") for e in pe)
        act_count=sum(e.get("type") not in NON_TACTICAL for e in pe)
        react_count=sum(e.get("type")=="defender_shift" for e in pe)
        if cam_count>1:
            warnings.append(f"phase {p['name']} has {cam_count} camera reframes")
        phase_report.append({
            "name":p["name"],"camera_reframes":cam_count,
            "tactical_actions":act_count,"defender_reactions":react_count
        })

    return {
        "version":cfg.get("version"),
        "duration_sec":duration,
        "ball_chain":chain,
        "final_holder":holder,
        "camera_reframes":len(cams),
        "phase_report":phase_report,
        "gaps":gaps,
        "final_hold_sec":round(final_hold,2),
        "errors":errors,
        "warnings":warnings,
        "valid":not errors
    }

def main():
    if len(sys.argv)<2:
        raise SystemExit("usage: tactical_execution_audit.py preset.json")
    p=Path(sys.argv[1])
    cfg=json.loads(p.read_text(encoding="utf-8"))
    print(json.dumps(audit(cfg),ensure_ascii=False,indent=2))

if __name__=="__main__":
    main()
