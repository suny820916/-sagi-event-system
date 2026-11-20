# V3.9 actual visual gate — 2026-11-20
Run 44684383287 successful; artifact 14606715924. Full MP4 decoded without errors; 540x960, 2100 video frames, 70.000 s. Execution report valid, exact-source visual acceptance pending. Nine actual frames inspected at 4/12/20/28/36/44/52/60/68 s.

FAIL visual gate: 4s pitch occupies too little screen; 12–68s excessive upper black area, 28s left pitch edge cropped, 36–52s focus relation remains distant, 60–68s players and ball too small. No new similarity score without canonical source comparison.

Next implementation: use evaluated camera projection of focal players and ball plus motion lookahead to fit a safe screen rectangle, reserve title zone, distinguish full-pitch establishing shots from intentionally cropped local shots, maintain temporal smoothing with hard visibility constraints. Test projection per frame, not just preset parameters. Preserve 70s master, V5.13 baseline and STANDARD closure. No claim of implementation or visual pass from this review.
