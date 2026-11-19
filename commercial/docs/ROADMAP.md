# Commercial V1.0 Roadmap

## Phase 0 — Isolation & standards
- [x] Create isolated commercial branch
- [x] Define offline-first architecture
- [x] Define Dev / Beta / Stable release policy
- [ ] Inventory current V4.40 functions (V4.31 baseline inventory completed; re-run after V4.40 Stable lands)
- [ ] Identify code that can be reused safely
- [ ] Build dependency and open-source license inventory (initial inventory created; full inherited asset scan pending)

## Phase 1 — Local Core
- [x] Define canonical MatchState schema
- [x] Define Event schema
- [x] Add append-only event journal
- [x] Add local persistence
- [x] Add crash recovery (durable full-state journal; stale snapshot/torn tail tests added; CI verification pending)
- [x] Add command idempotency
- [ ] Add health endpoint

## Phase 2 — vMix Adapter
- [ ] Standardize vMix connection
- [x] Input discovery (read-only XML snapshot parser; real vMix verification pending)
- [ ] overlay commands
- [ ] camera switching
- [ ] replay trigger
- [ ] retry / timeout strategy
- [ ] disconnected safe mode

## Phase 3 — Mobile Control
- [ ] LAN discovery / QR entry
- [ ] score
- [ ] clock
- [ ] goal
- [ ] cards
- [ ] substitution
- [ ] replay
- [ ] penalties
- [ ] state resync after reconnect

## Phase 4 — Auto Director
- [ ] Goal workflow
- [ ] Goal graphic / crest / player card
- [ ] Replay cue
- [ ] automatic return to program
- [ ] highlight marker
- [ ] persistent event
- [ ] player data update
- [ ] interruption / cancellation safety

## Phase 5 — Commercial shell
- [ ] Windows installer
- [ ] device identity
- [ ] license cache with offline grace period
- [ ] update channel selector
- [ ] signed release manifest
- [ ] rollback
- [ ] logs / diagnostics package
- [ ] local backup / restore

## Phase 6 — China production readiness
- [ ] remove runtime dependency on foreign CDN
- [ ] local font/assets packaging
- [ ] mainland-hosted optional cloud services
- [ ] ICP / app compliance checklist where applicable
- [ ] domestic network failure tests
- [ ] customer onboarding flow

## V1.0 acceptance goal

A new customer can install SAGI Broadcast on Windows, connect vMix, scan a QR code with a phone, run a full football match including a penalty shootout, survive temporary internet loss, restart the app without losing the match state, and export a complete event log.

## 2026-11-19 — Recovery hardening
- Added fsynced full-state commit records to journal, including non-event commands.
- Recovery prioritizes latest complete journal commit over stale/corrupted snapshots.
- In-process commit serialization prevents concurrent writes to the same store instance.
- Added test coverage for stale snapshots, duplicate command recovery, torn trailing journal record, malformed complete journal line, and stale revision rejection.
- **Known limits:** this is a development milestone, not certified commercial durability. Torn journal tail must be repaired/truncated before accepting new commits; concurrent separate processes writing the same store require a lock; disk-full and power-loss tests on Windows remain pending. A process restart must be gated by recovery checks before live use.

## 2026-11-19 — Local Engine API milestone
- Added dependency-free Node HTTP Local Engine, loopback by default, token auth, health endpoint, canonical state GET and serialized command POST.
- Commands commit durably before state is published; duplicate command IDs are idempotent and stale expectedRevision returns HTTP 409.
- Added self-test for authentication, concurrent duplicate goals, revision conflict and restart recovery.
- **Not yet production-ready:** LAN device pairing, token storage, CSRF/origin policy, transport security, WebSocket sync, multi-process locking, vMix adapter and actual Windows endurance tests remain open. CI result pending.

## 2026-11-19 — vMix adapter foundation
- Added dependency-free allowlisted vMix HTTP API adapter for Cut, Fade, overlays and recording controls.
- Added structured timeout/disconnect handling; no blind retries of ambiguous vMix side effects.
- Added isolated fake-transport tests and CI invocation.
- **Open:** real vMix hardware validation, input discovery, XML state reconciliation, durable cue outbox and Local Engine integration. Adapter alone is not an end-to-end live workflow.

## 2026-11-20 — vMix read-only input discovery
- Added bounded, dependency-free vMix XML status parser with active/preview input and input key/title/type/state discovery.
- Added fake-adapter tests for XML entities, duplicate/invalid inputs, disconnected vMix and malformed response.
- Added test to commercial CI.
- **Limits:** XML parser is intentionally narrow, not a full standards-compliant XML parser; no actual vMix Windows session was available. Input discovery is not yet wired to the Local Engine API and should not be marked live-certified.
