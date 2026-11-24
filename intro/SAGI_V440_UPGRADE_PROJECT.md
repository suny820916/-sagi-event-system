# SAGI vMix — SAGI SIGNATURE V4.31.0 → V4.40 Upgrade Project

Last context refresh: 2026-11-24

This is the persistent project brief for Codex and other engineering agents working on SAGI vMix. Repository state can move after this file is written, so always refresh GitHub branch/PR/CI state before making decisions.

## 1. Mission

Upgrade SAGI vMix SAGI SIGNATURE from the certified V4.31.0 baseline to V4.40 without sacrificing live-broadcast reliability.

The goal is not merely more features. V4.40 must be suitable for long-running football events in mainland China where overseas Internet access may be unavailable and only local LAN connectivity is dependable.

Primary design principle:

> Core live information survives; optional presentation degrades safely.

## 2. Current baseline and live gate

Certified stable rollback baseline:

- **V4.31.0**

Current staged development at time of this document:

- PR #27 — `SAGI vMix V4.33 · PENALTY SHOOTOUT CORE`
- Branch — `sagi-vmix-v433-penalty-system`
- PR is a Draft candidate and must not be described as production certified until physical acceptance gates are closed.

Relevant GitHub tracking:

- Issue #20 — V4.32 physical Windows/vMix/mobile/Overlay production certification evidence.
- Issue #21 — V4.34 GOAL PIPELINE.
- Issue #23 — mainland-China OFFLINE-FIRST / LAN-FIRST certification gate.

## 3. High-throughput execution mode

Every engineering round should consume as much safe, verifiable work as possible.

- Read the latest repo/branch/PR/CI/Issues once at the beginning.
- Work on the blocker nearest certification.
- Parallelize non-conflicting read-only analysis and tests.
- Group related code + tests + docs into coherent commits instead of many tiny commits.
- Run targeted tests after modification, then required complete regression/build.
- If a failure is fixable in code/config/tests, fix and rerun it in the same round.
- Do not stop merely because a CI run was triggered; do other safe work while it executes.
- Resolve safe merge conflicts or stale baselines in the same round.
- If the current version reaches its certification threshold, move immediately to the next version in the same round.
- Never advance version numbers to conceal an unresolved earlier defect.

## 4. Version roadmap

### V4.32 — SIGNATURE EVENT CORE

Goals:

- one shared EVENT component system;
- GOAL / SUB / YELLOW / RED share a Signature Core;
- standard event identity / idempotency;
- SAGI logo rules integrated into event packaging;
- preserve V4.31.0 core behavior and rollback.

Certification includes real Windows/phone/vMix/Overlay evidence from Issue #20.

### V4.33 — PENALTY SHOOTOUT

Goals:

- penalty state separated from normal score;
- kick identity and duplicate protection;
- correct home/away order;
- early mathematical winner;
- unlimited sudden death;
- Undo/reopen;
- refresh/restart/history recovery;
- phone/desktop/vMix consistency.

Do not certify from CI alone.

### V4.34 — REPLAY + BRAND TRANSITION + GOAL PIPELINE

After prerequisite certification, implement Issue #21.

One GOAL creates one `eventId` used by:

- score +1;
- GOAL event/animation;
- team crest;
- player photo/name/number;
- replay marker;
- highlight candidate;
- player statistics.

Required flow:

score commit
→ GOAL presentation
→ crest/player presentation
→ safe replay transition
→ mark/play latest safe Replay Event
→ ReplayStopEvents
→ return to MAIN_WIDE/configured main camera
→ persist event/highlight/stat relationships

Core score/event/player data commit first. Optional visuals and replay must fail into SAFE MODE.

Undo GOAL must reverse the score and all automatically-derived eventId-linked artifacts/statistics.

### V4.35 — FIXTURE / MATCH INFORMATION

Build consistent match/fixture/schedule presentation using the same Signature family. Keep fixture identity isolated so switching historical/current matches never leaks events between them.

### V4.36 — DATA BOARD

Consume player/team statistics derived from the event log. Do not create a second unrecoverable statistics source.

### V4.37 — STATE / RESTORE / PERSISTENCE

Strengthen:

- single source of truth;
- persisted state schema;
- event idempotency;
- reconnect;
- Bridge restart;
- browser reload;
- fixture switch;
- historical restore;
- cloud reconciliation rules.

Old cloud state must never overwrite newer live local state.

### V4.38 — LONG-RUN / FAULT TOLERANCE

Before certification:

- 4h minimum offline/LAN soak;
- 8h preferred soak;
- phone Wi-Fi disconnect/reconnect;
- Bridge restart;
- Browser Input refresh;
- overseas DNS/domain failure;
- no core dependency on external Internet;
- no timer/request queue/resource leak.

### V4.39 — UX / MOBILE / RELEASE CANDIDATE

Optimize live operation:

- Chinese information clarity;
- one-hand mobile use;
- fewer steps;
- obvious button state;
- anti-mistouch protection;
- safe destructive actions;
- reliable rapid operation;
- no automatic live core update.

### V4.40 — SAGI SIGNATURE COMPLETE

Only certify V4.40 when all earlier gates and Issue #23 are satisfied.

Required production condition:

- mainland-China normal network;
- no VPN/proxy requirement;
- full external Internet outage tolerated;
- only LAN available;
- long-duration stable operation;
- phone, desktop director, Bridge and vMix Browser/Overlay remain consistent.

Stop version advancement after V4.40 certification.

## 5. Highest-priority delivery blocker — SAGI AUTO TEST V1.0

The user has already reported a V0.6 Windows run with 14/14 passing. Treat that evidence as a baseline, not as a reason to skip V1.0 engineering.

V1.0 must be an isolated validation product that cannot damage a real match.

### Isolation

V1.0 must:

- use independent sandbox ports/state files;
- never POST to production port 8100;
- never issue real vMix commands to 8088;
- never mutate live match projects;
- use an explicit sandbox identity/token/namespace;
- abort rather than fall through to production if sandbox identity cannot be proven.

### Real UI test path

Do not validate only by directly calling rendering functions.

The test should interact with the actual control UI/buttons and observe state through independently-loaded clients/overlay.

Cover in bulk:

- score controls;
- GOAL/YELLOW/RED/SUB/CLEAR event controls;
- rapid/double clicks;
- retry idempotency;
- independent browser synchronization;
- visible GOAL animation;
- missing photo/crest/logo fallback;
- page refresh;
- disconnect/reconnect;
- sandbox Bridge restart;
- project/fixture isolation;
- state restore;
- screenshot capture;
- soak/long-loop stability.

### Evidence

A Windows CI run should produce:

- one self-contained V1.0 BAT;
- machine-readable test report;
- readable summary;
- screenshots where useful;
- logs;
- soak/resource metrics;
- artifact hashes where practical.

CI PASS is not real-device certification.

## 6. Single source of truth

The live state model must prevent:

- desktop correct / phone wrong;
- control correct / vMix output wrong;
- restored project reopening an older fixture;
- refresh causing a stale event animation;
- retry causing a second goal/card;
- cloud state overwriting more recent local state.

Event identity should be persistent enough to deduplicate replayed requests after refresh/reconnect.

## 7. OFFLINE-FIRST / LAN-FIRST rules

Core live operation must run completely from local packaged resources and local/LAN APIs.

Core must not require at runtime:

- GitHub Pages;
- Render;
- Google;
- jsDelivr;
- cdnjs;
- unpkg;
- SheetJS CDN;
- other overseas hosts.

External services can remain optional enhancements only.

Network requests for optional services require short timeouts and quiet SAFE MODE failure.

Dependencies needed for live file import should be packaged locally before commercial release.

## 8. SAFE MODE

Failure of any of the following must not take down score/time/team/card state:

- player photo;
- crest;
- SAGI Logo;
- event animation;
- replay;
- remote asset;
- cloud sync;
- update server;
- optional parser/importer.

Replay failure returns/stays on the safe main program view.

## 9. Required regression categories

Every release candidate must consider:

- repeated click;
- rapid operation;
- HTTP retry;
- refresh;
- network disconnect/reconnect;
- Browser Input reload;
- Bridge restart;
- fixture switch;
- historical restore;
- malformed/unexpected data;
- asset failure;
- animation failure;
- SAFE MODE;
- timer leakage;
- memory/resource leakage;
- long-session operation.

## 10. SAGI SIGNATURE design language

The following are one visual family:

- score bug;
- GOAL;
- substitution;
- yellow/red card;
- penalty board;
- replay transition;
- fixture/schedule board;
- data board.

Use:

- full SAGI FOOTBALL Logo for larger brand scenes;
- compact SAGI wordmark or A + red dot for small overlays;
- consistent typography hierarchy, spacing, radius, icon system and animation timing.

The brand red dot and red-card signal must be visually unambiguous.

Branding must never reduce readability of match information.

## 11. Release discipline

Never:

- silently modify the V4.31.0 rollback artifact;
- label a failed build as certified;
- merge a candidate merely because CI is green;
- require a VPN/proxy for live production;
- allow external services to become a hard dependency for core match operation;
- claim a real Windows/vMix/phone test happened when it did not.

When a version is truly certified, record:

- commit SHA;
- PR;
- CI runs;
- automated test evidence;
- physical acceptance evidence;
- known residual risks;
- rollback artifact/hash.
