# Mourinho V3.8 actual rendered visual gate — 2026-11-20

Source: GitHub Actions run 44664817598 (SUCCESS), artifact 14597398620, 70.000-second MP4, execution_report_v38.json, nine extracted frames (4,12,20,28,36,44,52,60,68 seconds).

## Result: FAIL — not visually accepted

The actual rendered frames were opened and inspected (not inferred from the render-success flag). The entire field and footballers remain too small relative to the frame; substantial black unused space persists. At 28s the left edge of the playing field is visibly cut off. At 36–52s the field sits too low and the heading is detached from the focal tactical action. At 60–68s the defensive relationships are not legible at ordinary viewing size; yellow/white silhouettes are tiny, and the ball is difficult to follow.

Technical assertions passed and the duration is exactly 70.000 seconds, but these checks do not prove camera safety, player readability, title positioning, or direct Teactics likeness. No numeric likeness score is awarded. Do not assert 99% acceptance.

## Required next engineering change

Do not repeat small min_z adjustments alone. Redesign camera framing using projected bounds of the focal players, ball and immediate passing lane, with target screen occupancy and a safe-title region. Detect clipping of field edges and focal subjects at every relation camera transition. Use close, low oblique longitudinal follow framing for the press trigger and defensive triangle, with a wider establishing shot only when needed for orientation. Keep the 70s master, Chinese yellow headings, V5.13 baseline, and exact SAGI_CLOUD_RENDER.mp4 source benchmark.

Before approving any subsequent version, inspect the complete MP4 and the execution report and extract transition frames in addition to the nine existing checkpoints. Preserve SAGI STANDARD V1.2 as CLOSED; do not render V1.3.
