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
- [x] Add health endpoint (loopback Local Engine)

## Phase 2 — vMix Adapter
- [ ] Standardize vMix connection (authenticated read-only status integrated; cue path still separate)
- [x] Input discovery (read-only XML snapshot parser; real vMix verification pending)
- [ ] overlay commands
- [ ] camera switching
- [ ] replay trigger
- [ ] retry / timeout strategy
- [ ] disconnected safe mode

## Phase 3 — Mobile Control
- [ ] LAN discovery / QR entry (isolated pairing primitive implemented; HTTP/UI integration pending)
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

## 2026-11-20 — Local Engine vMix status integration
- Added authenticated GET /api/v1/vmix/status, backed by injected vMix adapter and existing bounded XML parser.
- vMix not configured/disconnected/invalid status returns 503 without blocking local match state or score commands.
- Added test for unauthorized status access, Chinese camera names, active/preview discovery, disconnected vMix and match state availability.
- Wired new test into commercial CI. CI result and real Windows/vMix validation pending.
- **Next:** durable cue outbox, explicit input allowlist, read-back verification, LAN pairing and state synchronization. Do not treat vMix HTTP acknowledgement as confirmed on-air transition.


## 2026-11-20 — Isolated LAN pairing prototype
- Added dependency-free `commercial/lan/lan-pairing.mjs` with locally approved one-time codes, attempt limits, expiring sessions and revocation.
- Added deterministic Node self-test and separate CI workflow.
- Locally verified: `node commercial/lan/lan-pairing-selftest.mjs` PASS.
- **Not integrated:** trusted desktop approval, HTTP endpoint, client-IP rate limiting, LAN firewall/origin/host controls, mobile UI, and Windows security review. The module must not be advertised as secure production pairing until those are implemented and tested.

## 2026-11-20 — LAN pairing resource hardening
- Replaced modulo-based six-digit pairing code generation with cryptographic `randomInt` to avoid modulo bias.
- Added bounded active sessions (`maxSessions`, default 16) and expiry pruning before new session admission.
- Added tests for session exhaustion, revocation, expiry reclamation and invalid configuration.
- **Verification status:** GitHub commits created; automated CI and real Windows/LAN validation not confirmed in this run. Container clone failed because github.com DNS resolution was unavailable; do not report test PASS.
- **Open security work:** rate limit by source address, operator-initiated approval boundary, LAN HTTP integration, origin/host protections, and pairing token scope. No production security certification.

## 2026-11-20 — Experimental LAN HTTP gateway
- Added `commercial/lan/lan-gateway.mjs` and self-test for health, one-time code redemption, session-authorized state reads, revocation, browser Origin rejection and source-IP rate limits.
- LAN binding requires an explicit IP interface; wildcard listeners are rejected. Default is loopback.
- Deliberately **disabled** HTTP pairing-code issuance: local loopback access alone is not proof of physical operator approval. Codes may only be issued by a trusted desktop integration.
- Added gateway checks to LAN pairing CI. Local isolated HTTP prototype test passed on Node 22; CI result remains unverified.
- **Not production-ready:** gateway is not wired to the canonical Local Engine; no LAN TLS or authenticated operator UI, no device permission scopes, no persistent rate limiting, no real Windows/vMix testing. Treat source IP throttling as defense-in-depth, not an authentication boundary.

## 2026-11-20 — Authenticated LAN command bridge
- Added `POST /api/v1/lan/command` to experimental LAN gateway. Requires an active paired bearer token and a bounded command envelope (`commandId`, `expectedRevision`, `type`).
- The bridge delegates to an injected `submitCommand` callback; it does **not** independently mutate match state or execute vMix commands. The canonical Local Engine must enforce the command allowlist, revision checks and durable idempotency.
- Added self-test for unauthorized access, invalid envelopes, duplicate IDs, stale revision conflict, state read-back and revoked session.
- Added command self-test to the existing LAN CI workflow.
- **Not yet integrated:** canonical Local Engine callback wiring, per-device scopes, encrypted LAN transport, mobile UI, Windows/vMix hardware validation. HTTP status 200 only confirms the injected callback response, not broadcast/on-air confirmation. CI result not verified in this run.

## 2026-11-20 — LAN command boundary hardening
- LAN POST requests now require an explicit application/json content type.
- Paired mobile sessions cannot forward arbitrary administrative or vMix operations: the gateway applies a narrow football-command allowlist before invoking the injected callback.
- Extended LAN command self-test with denied privileged commands and missing content type.
- **Verification:** GitHub commits recorded; no CI workflow run was returned for the latest commit at time of inspection. No claim of test PASS or live integration.
- **Compatibility caution:** this provisional allowlist must be reconciled with canonical Local Engine command names before integration. It intentionally fails closed for unknown types.
- **Still open:** true Local Engine wiring, per-device permissions, encrypted transport, end-to-end idempotency and state recovery, Windows and actual vMix validation.

## 2026-11-20 — LAN command syntax repair
- Audited the committed LAN gateway and command self-test via GitHub file API and found literal `\\n` text embedded between JavaScript statements in both files, a parse-blocking defect.
- Replaced the embedded escaped-newline sequences with actual newlines in `commercial/lan/lan-gateway.mjs` and `commercial/lan/lan-command-selftest.mjs` (commits `501eefb`, `79970f1`).
- **Verification:** fetched source inspection confirmed the defect before patch; GitHub contents API accepted both file updates. Local `node --check` and self-tests could not be executed because the runner could not resolve github.com for clone. CI remains unverified. Do not mark the LAN command bridge as tested or production ready.
- **Next:** run Node syntax checks and all LAN tests in CI; reconcile mobile command types with canonical engine and wire the gateway only after verified tests.

## 2026-11-20 — LAN Host-header boundary
- Reject HTTP requests with a Host header not matching the explicitly bound interface; permit localhost alias only for loopback binding. This limits DNS-rebinding / forged-host exposure of the experimental gateway.
- Added a negative Host-header test to the existing LAN command self-test.
- Commits: `c9cb8ad` (gateway), `fcaa6d3` (test).
- **Verification:** source changes committed through GitHub API; Node syntax, test execution and CI status are not yet confirmed. Do not treat this as a complete LAN security solution: plaintext bearer tokens, phone browser Origin handling, physical operator approval and actual Windows LAN testing remain open.

## 2026-11-20 — LAN Host authority validation follow-up
- Hardened Host parsing to reject userinfo, path/query fragments, whitespace and missing explicit port, instead of trusting URL hostname alone. Corrected IPv6 bracket removal (prior expression had incorrect escaping).
- Added malformed-Host negative tests in `lan-command-selftest.mjs`.
- Commits: `3092c66`, `a6d1570`, `e15772e`.
- **Verification pending:** GitHub API accepted changes, but no Node execution or actual Windows/mobile LAN test was performed in this run. A passing CI result is required before treating this fix as validated.
- **Important compatibility limitation:** browser Origin requests are still unconditionally rejected, so the current HTTP gateway cannot be considered a working phone-browser control UI. TLS, operator approval, canonical Local Engine integration, and end-to-end state synchronization remain outstanding.
