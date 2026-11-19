# Mourinho V3.5 vs Teactics — evidence gate (2026-11-19)

Status: RENDERED, NOT VISUALLY CERTIFIED. This is a review record, not a new version or render request.

## Verified artifact
- Run: https://github.com/suny820916/-sagi-event-system/actions/runs/44603540020
- Artifact: 14570383593
- MP4: `mourinho_v35_out/SAGI_MOURINHO_70S_V35_SCREEN_READABILITY.mp4`
- Duration: 70.000 seconds (ffprobe)
- Includes `execution_report_v35.json`, nine critical JPEGs, scene.blend, preset and ASS overlay.
- Report ball-chain finishes at `O_LB`; phases end at 70 seconds. Report success is not proof of visual equivalence.

## Direct reference comparison
Canonical original: `SAGI_CLOUD_RENDER.mp4`; regression reference: V5.13.
Extracted synchronized frames at 2, 8, 23, 31, 40, 50, 59 and 67 seconds. These times are useful for screen geometry but MUST NOT be interpreted as tactical-beat alignment: original and Mourinho tell different stories.
V3.5 still exhibits undersized tactical figures, too much unused upper black space, and insufficient close-up causal relationship shots in compact-block phase (53–70s). No evidence supports upgrading the historical provisional V3.3 score of 47/100.

## Required next render acceptance gate
1. Prototype a new camera composition on Mourinho branch ONLY. Preserve 70s locked narrative and V5.13 figure baseline. Do not touch STANDARD V1.2.
2. Fix vertical layout: reserve top for short yellow thesis, enlarge active 2–4 player relationship while preserving enough context to understand movement; test safe margins at 540x960.
3. At 53–70s, show trigger -> compact defensive shift -> triangle protection -> 4-4-1-1 recovery with at least one legible relationship close-up. No static wide shot replacing the entire chain.
4. Capture the eight synchronized moments and additional tactical-beat matched frames; inspect full MP4 and report. Record actual 100-point rubric before claiming improvement.
5. Reject any regression relative to V5.13, and do not claim 99% without source-backed full-motion verification.

SAGI STANDARD EVENT-FLOW is CLOSED at V1.2; this review must not trigger it.
