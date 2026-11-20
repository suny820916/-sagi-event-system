# Mourinho V3.7 visual gate — 2026-11-20

## Verified run
- GitHub Actions run: 44651254661 (success, 2026-11-20 01:17 UTC).
- Artifact: 14590774558, 14 files, expires 2026-12-20.
- MP4: SAGI_MOURINHO_70S_V37_DEFENSIVE_RELATION.mp4; ffprobe duration 70.000000 seconds.
- execution_report_v37.json present; phase_report spans 0–70 seconds.
- Nine JPEG frames inspected at 4, 12, 20, 28, 36, 44, 52, 60, 68 seconds.

## Actual visual review (NOT a 99% pass)
- Frames 4/12/20: field sits low with extensive black space; player/ball readability remains weak.
- Frame 28: pitch partly clipped at left/bottom during closer relationship shot. A tighter shot must not remove relevant player context.
- Frames 36/44/52: action grouping remains small and distant; yellow headings are separated from the field by large empty regions.
- Frames 60/68: defensive relationship is still hard to read at thumbnail size; 68 has no readable stage title.
- Still images alone cannot establish smooth player-ball contact or continuous tactical causality. A dynamic source-video comparison is still mandatory.
- 47/100 is a prior V3.3 subjective reference only, NOT a measured V3.7 score.

## Next production gate
1. Reframe the vertical composition globally so field + tactical actors occupy more of the useful canvas without cropping required context; keep the Chinese yellow heading close to the focal zone.
2. For 53–70s, explicitly frame the 3–6 relevant actors with support context, and preserve complete ball path.
3. Sample additional frames before/after each camera transition, inspect whole MP4 and compare against canonical SAGI_CLOUD_RENDER.mp4 and V5.13 baseline.
4. Render a new version only after checking shot framing constraints; retain Mourinho's 70-second Production Master.
5. Do not reopen SAGI STANDARD; its V1.2 branch remains closed by user instruction.

Status: TECHNICAL PASS, VISUAL FAIL, 99% NOT VERIFIED.
