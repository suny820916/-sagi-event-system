# Commercial V1.0 Roadmap

## Phase 0 — Isolation & standards
- [x] Create isolated commercial branch
- [x] Define offline-first architecture
- [x] Define Dev / Beta / Stable release policy
- [ ] Inventory current V4.40 functions
- [ ] Identify code that can be reused safely
- [ ] Build dependency and open-source license inventory

## Phase 1 — Local Core
- [ ] Define canonical MatchState schema
- [ ] Define Event schema
- [ ] Add append-only event journal
- [ ] Add local persistence
- [ ] Add crash recovery
- [ ] Add command idempotency
- [ ] Add health endpoint

## Phase 2 — vMix Adapter
- [ ] Standardize vMix connection
- [ ] Input discovery
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
