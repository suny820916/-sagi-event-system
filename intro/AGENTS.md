# SAGI vMix agent instructions

Scope: all SAGI vMix / SAGI SIGNATURE work under this `intro/` directory.

## Mandatory context

Before editing code, read:

- `SAGI_V440_UPGRADE_PROJECT.md`
- GitHub Issue #20 — physical Windows/vMix/mobile/Overlay certification blocker
- GitHub Issue #21 — V4.34 GOAL PIPELINE
- GitHub Issue #23 — China OFFLINE-FIRST / LAN-FIRST certification gate
- Current open SAGI vMix PRs and their latest CI results

Do not rely on old conversation summaries when repository state has changed.

## Certified baseline and current candidate

- Certified rollback baseline: **V4.31.0**.
- V4.31.0 must remain recoverable and must not be silently rewritten.
- Current staged candidate at time of this file creation: **PR #27**, branch `sagi-vmix-v433-penalty-system`, V4.33 Penalty Shootout Core.
- PR #27 is still a draft candidate, not a production-certified release.
- A green GitHub Actions run is automation evidence, not proof of real vMix/phone/Windows operation.

Always re-read the current GitHub state before acting because the branch head may advance after this document is written.

## Highest-priority delivery blocker: SAGI AUTO TEST V1.0

Build and validate AUTO TEST V1.0 before treating manual acceptance tooling as finished.

Requirements:

- Preserve the user's already-passed V0.6 Windows evidence as a baseline; do not overwrite or reinterpret it.
- AUTO TEST V1.0 must run in an **independent sandbox**.
- It must not write to the production Bridge on port 8100.
- It must not send real vMix control commands to port 8088 or mutate a live match.
- Use an isolated Bridge/state namespace and isolated ports.
- Exercise the real control UI/buttons rather than only calling rendering functions directly.
- Validate at least:
  - score and event button behavior;
  - duplicate/rapid input idempotency;
  - independent browser/control/overlay synchronization;
  - GOAL animation and core-score survival if visual assets fail;
  - refresh/reload recovery;
  - simulated disconnect/reconnect;
  - sandbox Bridge restart and state recovery;
  - fixture/project isolation;
  - screenshots/evidence capture;
  - long-session/soak behavior and timer/resource stability.
- Windows CI must parse and execute the V1.0 sandbox gates.
- Deliver a single self-contained BAT plus evidence/artifacts.
- Do not publish a sequence of fake intermediate releases.
- Do not call V1.0 "physical real-device certified" unless a real Windows/vMix/phone acceptance run actually happened.

## Version gates

Progress in order. Do not use a later version number to hide an unresolved earlier gate.

- V4.32 — unified EVENT components + shared SAGI SIGNATURE Core; GOAL/SUB/YELLOW/RED; brand skeleton.
- V4.33 — penalty shootout system.
- V4.34 — replay + event/SAGI Logo transition + GOAL PIPELINE.
- V4.35 — fixtures/match information.
- V4.36 — data board and player stats consumers.
- V4.37 — stronger SSoT, persistence, restore, reconnect, idempotency.
- V4.38 — long-duration and fault-tolerance hardening; China offline/LAN soak.
- V4.39 — UX/mobile/anti-mistouch/release candidate.
- V4.40 — SAGI SIGNATURE COMPLETE final stable certification.

A version may advance in the same work session immediately after all certification gates pass.

## Engineering invariants

1. Stability and safety are more important than visual effects.
2. Score, clock, team identity and cards must keep working if optional graphics fail.
3. Bridge/local persisted state is the authoritative live state; phone, desktop and vMix Browser/Overlay must converge on the same truth.
4. Event operations must be idempotent under double-click, rapid taps and HTTP retry.
5. SAFE MODE must degrade animation/photo/crest/logo/replay without destroying core state.
6. Refresh, reconnect, Browser reload, Bridge restart, fixture switch and historical restore must not replay stale events or cross-contaminate fixtures.
7. No production runtime may require GitHub Pages, Render, Google, jsDelivr, cdnjs, unpkg, SheetJS CDN or other overseas services for core live operation.
8. Live match operation is LAN-FIRST / OFFLINE-FIRST. Cloud/update paths are optional, asynchronous and isolated from live state.
9. Do not auto-update core live code during a match.
10. After any code change: run affected fast tests, then the repository-required full self-test/build/regression. Fix failures before marking a gate closed.

## SAGI SIGNATURE visual system

All score bug, GOAL, substitution, cards, penalty board, replay transition, fixture board and data board belong to one SAGI SIGNATURE family.

- Full SAGI FOOTBALL Logo: large-space scenes such as replay transition, fixture/data/start/brand pages.
- Small live overlays: use the SAGI wordmark or A + red-dot identity sparingly.
- The brand red dot must never be confused with a red-card indicator.
- Keep typography hierarchy, spacing, corner radius, icon language and animation tempo consistent.
- Information readability always wins over branding.

## Reporting

At the end of a work round report only verified facts:

- actual files/code changed;
- commit(s) / PR(s);
- tests actually executed and their result;
- CI run status;
- certification gates closed;
- remaining real blockers;
- current candidate version;
- certified rollback baseline.

Never report "plan to do" as completed work.
