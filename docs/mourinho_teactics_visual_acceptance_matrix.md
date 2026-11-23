# Mourinho / Teactics 70s visual acceptance matrix

Status: QA specification only; **not** a certification or a claim of 99% similarity.
Canonical reference: user-provided `SAGI_CLOUD_RENDER.mp4`. Production duration: 70.000 s.
Baseline: V5.13. Scope: Mourinho tactical-animation branch only.
SAGI STANDARD V1.2 is CLOSED. Do not modify or rerender it.

## Hard gates (all must pass before visual scoring)
1. Rendered MP4 exists, 70.000 s within one frame tolerance; ffprobe reports intended FPS, resolution, and complete stream.
2. Full video decodes without error (not merely the first few frames).
3. Engine report exists and corresponds to the same commit/artifact as the MP4.
4. At least nine timestamped critical frames exist, with exact source timestamps.
5. Chinese main title and yellow section titles are complete and legible within title-safe region.
6. No missing ball, player clipping, camera jump, or scene blackout.
7. No changes to STANDARD branch, main, or certified baseline.

## Reference comparison: never claim a numerical score without both actual videos
For each of nine evenly sampled segments (plus cuts/action boundaries), record:
- **Framing**: pitch occupies intended screen area, low oblique view, no excessive lateral pan, meaningful longitudinal following.
- **Visual hierarchy**: focal player/ball distinguishable from support/context; small thick-body characters remain readable.
- **Cause-effect**: pressing trigger -> opponent reaction -> turnover -> 3-second transition -> final action; defensive shape remains coherent.
- **Action continuity**: support-foot, contact, body orientation, ball trajectory and defensive response agree frame-to-frame.
- **Editorial timing**: each point has observation -> action -> reaction -> space revealed -> brief hold, without dead time.
- **Typography**: yellow Chinese headers and subtitle timing never hide active tactical relation.
- **Similarity evidence**: side-by-side reference frame and rendered frame, matched by semantic beat (not forced timestamp alignment).

## Required report fields
`commit_sha`, `workflow_run_url`, `artifact_id`, `mp4_path`, `duration_seconds`,
`decode_pass`, `report_path`, `critical_frame_paths`, `reference_available`,
`comparison_notes`, `blocking_findings`, `visual_acceptance`.

`visual_acceptance` must be `NOT_EVALUATED` if either MP4 or canonical source is unavailable.
Never infer a 99% match from CI green status. Fix highest-impact mismatch first and rerender
on the isolated Mourinho branch. Preserve the 70-second locked tactical cause-effect chain.
