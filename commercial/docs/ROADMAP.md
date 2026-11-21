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

## 2026-11-20 — Same-origin browser compatibility and Host-port validation
- Updated experimental LAN gateway to accept browser requests only when the Origin exactly matches the HTTP Host authority (same scheme, host, port); foreign and malformed origins remain forbidden. No wildcard CORS is enabled.
- Host validation now also checks the actual listening TCP port, preventing Host authorities pointing at another port from being accepted.
- Added negative and positive HTTP regression cases to `commercial/lan/lan-command-selftest.mjs`.
- Commits: `f01f6dbc` (gateway), `09888b1` (tests).
- **Verification pending:** GitHub API accepted source and test commits; neither Node execution nor Windows/mobile hardware testing has been confirmed. Treat this as code review progress, not a certified browser connection.
- **Still open:** local desktop approval UI, actual LAN TLS or equivalent protected pairing-token transport, canonical engine integration, replay/vMix end-to-end tests, security review and commercial packaging. The browser must load from the gateway's exact origin; a separately hosted UI is intentionally blocked.

## 2026-11-20 — LAN request-target canonicalization
- Reject non-origin-form, query-bearing, percent-encoded and malformed LAN API request targets before routing; do not silently normalize alternate spellings of privileged endpoints.
- Added negative HTTP tests for query, encoded route aliases and double-slash targets.
- Commits: `c093ef5`, `a692dfc`, `bfd12cc`.
- **Verification:** GitHub accepted source/test updates; Node syntax checks and LAN tests have not yet run in this execution. No claim of CI PASS or Windows/mobile validation.
- **Next:** verify LAN CI and connect canonical Local Engine with durable idempotency. Do not expose this experimental HTTP gateway to untrusted networks; plaintext paired-device bearer tokens and missing end-to-end device controls remain release blockers.

## 2026-11-20 — LAN socket lifetime bounds
- Set explicit HTTP request/header/idle/keep-alive timeouts and a maximum of 100 requests per socket in the experimental LAN gateway, preventing abandoned connections from remaining open indefinitely.
- Added assertions for these settings to the existing LAN command self-test.
- Commits: `2b8f786` (gateway), `f69e1ce` (test).
- **Verification:** source and test committed through GitHub API. Local clone failed due to GitHub DNS resolution; Node execution and GitHub Actions CI are not confirmed. The configuration assertions do not substitute for a real slow-client/endurance test.
- **Release blockers remain:** connect LAN Gateway to canonical Local Engine, persist idempotent commands, validate phone/vMix on Windows, protect bearer tokens on LAN, and test recovery under power loss. Prioritize those integration milestones over further isolated gateway hardening.

## 2026-11-20 — LAN → Local Engine integration acceptance gate
- Added `commercial/docs/LAN_ENGINE_INTEGRATION_GATE.md` documenting source-observed integration gaps and ten concrete acceptance tests.
- Confirmed the current LAN command self-test uses an in-memory fake callback; it does not validate canonical engine persistence, restart idempotency, WAN outage or vMix readback.
- **Verification:** documentation committed; no Node/CI/Windows/vMix test was executed in this run. All ten integration checks remain pending. No production readiness claim.
- **Priority:** connect gateway to canonical durable engine with an explicit adapter and implement real restart/reconnect tests before further LAN gateway micro-hardening.

## 2026-11-20 — Canonical LAN engine bridge
- Added loopback-only HTTP adapter using the existing authoritative engine, with bounded timeout and no automatic retries. Engine token stays server-side.
- Reconciled mobile allowlist with canonical command types and propagated invalid-command and revision-conflict responses.
- Added real engine/store integration self-test covering concurrent goals, restart/re-pair, durable duplicate detection, red card and offline engine response.
- Commits: 89b41c1, d3680fc, 7252f5d. Runtime verification pending; no live certification. Clock progression, long-window idempotency (2048 ID cap), store writer locking, transport security, vMix cues and Windows/mobile tests remain open.

## 2026-11-20 — Durable commit / snapshot failure boundary
- Fixed a source-observed consistency defect: after a journal record was fsynced, a snapshot failure previously caused the Local Engine to return failure and retain stale in-memory state. Snapshot replacement is now best-effort after the durable commit; the old snapshot is never deleted as a fallback. Snapshot error is retained in the store instance for future diagnostics.
- Added `commercial/core/snapshot-failure-selftest.mjs` covering actual HTTP goal submission, duplicate retry and restart with a deliberately obstructed snapshot path.
- Commits: e5a375b, d37fab92. Test execution and CI pending; uncertain journal writes, disk-full, writer locking and torn-tail repair remain release blockers. The snapshot warning still needs a diagnostics endpoint.

## 2026-11-20 — Storage recovery gate and diagnostics
- Latch uncertain journal write/sync/close failures; refuse further mutations until restart and recovery. Health reports HTTP 503 while latched; authenticated diagnostics exposes sanitized journal and snapshot warnings without local paths or tokens.
- Extended snapshot failure self-test with diagnostics auth and injected recovery latch checks. This does not simulate an actual disk write/sync failure.
- Commits: 616c695, fff543b, 55cad51. Runtime tests remain pending. A complete but unsynced record, torn tail, writer locking, actual Windows disk-full/power loss and operator recovery UI remain release blockers. Reads may represent the last confirmed in-memory state while recovery is required; do not treat them as current on-air confirmation.

## 2026-11-20 — Torn journal startup recovery gate
- Detect incomplete JSONL tail during recovery, retain last complete state but latch recovery-required immediately; new commands are blocked and health returns 503. Append-open errors also latch the store.
- Extended snapshot failure integration self-test with actual incomplete tail bytes, restart, state readback and refusal of new goal. Commits: c51fa28, 992dcdb.
- Runtime verification pending. No automatic truncation or repair is attempted; preserve evidence and require exclusive writer coordination before implementing repair. Windows disk failure and power-loss tests still required.

## 2026-11-20 — Independent writer exclusion
- Added atomic directory lock around FileMatchStore commit, including revision checks and journal/snapshot writes. Existing locks are never automatically stolen. Release failure latches the store without negating a durable commit.
- Extended recovery self-test to exercise lock contention, stale revision and lock cleanup. Commits: 01a332a, b1f8cb4.
- Limits: commit lock is not a lifetime engine ownership lock; multiple engines can still serve stale reads. Crash residue requires safe operator recovery; do not remove lock while a writer may be alive. Node/Windows execution pending. Next: exclusive engine ownership, recovery UI and actual concurrent process tests.

## 2026-11-20 — Engine lifetime ownership
- Local Engine reserves an atomic directory lock before loading state; a competing engine for the same data directory fails closed. Graceful shutdown drains server and command queue before removing ownership. Failed startup releases ownership.
- Extended recovery self-test with competing engine and listener startup failure cases. Commits: 0f2b3af, b1744e7.
- Crash residue intentionally blocks restart; safe offline operator recovery, direct store writer coordination, multiprocess tests and Windows verification remain required. Runtime tests not confirmed. No new dependencies.

## 2026-11-20 — Match clock and shootout identity corrections
- Stop clock on HALF_TIME and FINISH_PENALTIES, preserving elapsed seconds. Continuous authoritative clock progression remains unimplemented.
- Derive penalty attempt IDs from monotonic event sequence, not capped history length, preventing new collisions after 200 attempts. Existing historical IDs are not migrated.
- Added reducer regression assertions for 205 attempts and clock stopping to snapshot-failure self-test. Commits: 473f0c5, 323816f. Runtime/CI and Windows validation pending; no new dependencies. Engine crash-lock recovery remains open.

## 2026-11-20 — Match-wide idempotency retention
- Removed the 2048-command eviction from reducer and hydration so delayed retries of early goals remain duplicates throughout a fixture, including serialization/reload. Commits: 239c4d2, fb8db0c.
- Added reducer regression after 2050 subsequent operations; runtime execution pending. Previously evicted IDs in existing data are not reconstructed by this change.
- Tradeoff: full-state journal and retained IDs grow with fixture size; benchmark storage/latency and migrate to a durable indexed command ledger before commercial endurance certification. Existing event/history retention limits remain separate export blockers.

## 2026-11-20 — Complete fixture history retention
- Removed reducer/hydration caps on event log, replay markers and penalty history to preserve complete new-fixture records. Commits: ca09091, 2a84211.
- Added regression assertions for 1002 events/markers after serialization and 205 penalty attempts. Runtime/CI not yet verified. Previously truncated histories are not reconstructed; full-state journal size and serialization costs remain endurance risks. Export UI and durable indexed ledger remain open.

## 2026-11-20 — Auditable score corrections
- SCORE_ADJUST now records before/after and requested/applied delta in the canonical event history without creating a replay marker. Reject non-safe-integer or out-of-range deltas (absolute maximum 100 per command). Commits: 8686bf5, bf668e9.
- Added reducer assertions for clamped correction, duplicate retries, invalid deltas and unchanged replay markers. Runtime/CI not verified; historical unlogged corrections cannot be reconstructed from event history alone. Consumers must recognize the new event type before live deployment. No new dependencies.

## 2026-11-21 — Strict score correction payloads
- Reject non-number deltas instead of coercing null, booleans, strings and arrays into score corrections. Added regression cases. Commits: ba8a5a2, 65f6290.
- Runtime and CI verification pending; clients must send numeric JSON deltas. No new dependencies.

## 2026-11-21 — CI coverage closure
- Verified baseline commit `85e8350`: GitHub Actions run 44769721281 passed all six existing Linux core/API/vMix simulated tests. The accumulated snapshot-failure self-test was absent from that workflow, so baseline green does not verify those regressions.
- Added `commercial/core/snapshot-failure-selftest.mjs` to core CI and expanded matrix to Ubuntu and Windows, with independent failure reporting (commit b9024e6). New matrix results pending; simulated Windows runner does not certify real vMix, power loss or endurance.
- Next gate: inspect both matrix jobs and fix any failures before feature expansion.

## 2026-11-21 — Dual-platform core verification and LAN CI repair
- PR merge CI run 44779949465 for c97e3b8 passed all seven core/API/vMix simulated test steps on both Windows and Ubuntu (14/14), including accumulated storage and retained-history regressions.
- LAN run 44779949409 failed on Ubuntu: legacy issue-endpoint test expected 403 but omitted required JSON content type, correctly receiving 415. Windows was cancelled by matrix fail-fast.
- Updated tests to assert both JSON rejection and desktop approval denial, and use the actual port for the forbidden-host test; disabled LAN matrix fail-fast. Commits 72d0c0d, 779829a, e14100c. Security checks were not weakened.
- Repaired LAN suite execution pending. Real phone/Windows/vMix operation, encrypted transport, production startup and endurance remain unverified. No new runtime dependencies.

## 2026-11-21 — LAN Host regression harness repair
- Core run 44792966144 passed seven runtime test steps on each of Windows and Ubuntu (14/14).
- LAN run 44792966009 failed on both platforms at the command self-test; Ubuntu log reports line 43 actual 200 versus expected 403 for the forged Host probe. Both pairing and gateway suites passed; canonical bridge tests were skipped.
- Replaced fetch-based Host overrides with explicit node:http requests (commit 594cc57) so the test sends the intended authority. Added probe timeout; production gateway and security policy unchanged. Repaired test execution remains pending; do not claim that the Host defense or bridge passed.
- Full Preflight run 44792966073 failed at Flask API smoke test, outside the commercial core suite; no changes made to inherited application or main. Release remains blocked pending LAN CI and actual Windows/vMix/endurance validation.

## 2026-11-21 — LAN authority normalization review
- Validate explicit Host port from raw authority before URL parsing, reject alternate IPv4 spellings and padded ports, and require exact serialized browser Origin. This also avoids relying on URL.port for explicit default ports.
- Added regression probes for alternate IPv4 authorities, padded ports and noncanonical Origin paths. Commits: 088868a, c16c3d6.
- No workflow runs were returned by the PR-filtered lookup for b1e25b9; latest LAN verification remains unknown. New tests not executed in this run. Canonical IPv6 spelling and default-port browser behavior still need dedicated tests. No new dependencies or main changes.

## 2026-11-21 — Clock command validation
- SET_CLOCK rejects non-boolean running and non-safe-integer or negative elapsed seconds. SET_PERIOD stops the clock when selecting PRE, HT, ET_BREAK, PEN or FT, retaining elapsed seconds. Commits: e6ce7dd, b26fc5c.
- Added reducer regression cases to the existing core CI suite. Execution not verified in this run. Clients must send both clock fields with canonical JSON types. Explicit SET_CLOCK remains an operator override; continuous authoritative progression and restart policy are not implemented by this patch.
- No new runtime dependency or main change. Next: verify CI, reconcile client payloads, establish monotonic clock anchor and restart policy, complete LAN/vMix integration and endurance acceptance.

## 2026-11-21 — Monotonic clock foundation
- Added dependency-free runtime clock using Node performance.now(), whole-second projection and explicit operator override. A persisted running checkpoint is held paused on startup with recoveryPending; downtime is not silently counted.
- Added deterministic fake-time self-test for progression, pause, restart hold and invalid input. Commits: 271fe7c, aa43bd4.
- Verification: source and tests committed; Node/CI execution not confirmed. Not wired into Local Engine or LAN UI. Next: materialize clock checkpoints at durable command boundaries, preserve fractional progression across unrelated commands, expose authoritative clock and recovery status consistently, and implement periodic durable checkpoints plus operator recovery. Do not treat this as live-certified timing.


## 2026-11-21 — Authoritative HTTP match clock integration
- Local Engine now projects a single monotonic runtime clock on state reads and command replies; ticking does not advance command revision. Non-clock commands checkpoint elapsed seconds without resetting the runtime anchor.
- Clock updates occur only after durable command commit; a running checkpoint recovered after restart is exposed as paused with clockRecoveryPending until explicit clock/phase action. No internet time service required.
- Extended HTTP regression for ticking, revision stability, yellow-card checkpoint and restart without counting downtime. Standalone clock test added to Windows/Linux CI.
- Commits: 841ed59, ad7946c, ec79b3d. Prior core CI run 44826325683 succeeded, but did not include the standalone clock test. New CI pending at time of writing.
- Open: periodic durable checkpoint and graceful-close checkpoint (idle running clock can lose time since last command), LAN gateway wiring, vMix display sync, real machine endurance and power loss tests. Not release certified.

## 2026-11-21 — Durable clock checkpoints
- Added clock-only same-revision journal commits under the existing writer lock; reject changes to non-clock state, backward elapsed time and non-running checkpoints. No match event or command ID is generated.
- Local Engine schedules checkpoints every 15 seconds by default, coalesces pending work through its command queue, saves again on graceful close and exposes a sanitized checkpoint warning in diagnostics.
- Extended HTTP self-test for periodic persistence, unchanged revision, rejection of score mutations through checkpoint path and graceful restart recovery. Commits: ffcc8ef, afd5ab9, a48c62d.
- Runtime/CI verification pending. Full-state checkpoint records increase journal growth; benchmark long fixtures and disk latency. 15 seconds is a target interval, not a guaranteed loss bound under stalled I/O or shutdown failure. Crash-lock operator recovery and real Windows/vMix acceptance remain release blockers.

## 2026-11-21 — Journal read amplification reduction
- Removed redundant full journal read from locked commit path; `_entries()` now provides both parsed entries and torn-tail latch. Reject latched tail before appending. Commit 7653db4.
- No format, retention, revision or dependency changes. Existing recovery tests must be rerun; no runtime/CI result verified for this change. Full journal parsing and full-state checkpoint growth remain endurance blockers; benchmark before introducing a bounded durable index.

## 2026-11-21 — Checkpoint performance baseline harness
- Added real FileMatchStore benchmark executing 240 durable checkpoints (one simulated match hour) and checking recovery, stable revision, original goal idempotency, and preserved journal event count. Reports journal bytes and p50/p95/max latency.
- Wired benchmark into Windows/Linux core CI. Commits: 15fc9ae, b45d8f6. Execution not yet verified; this is accelerated correctness coverage, not a real one-hour or 24-hour soak, and metrics have no performance pass threshold yet.
- Next: inspect measured baseline, extend under realistic retained command/event history, set hardware-specific latency budgets, then optimize storage without weakening corruption detection or writer exclusion. No new runtime dependencies.

## 2026-11-21 — Retained-history checkpoint benchmark
- Expanded the existing 240-checkpoint benchmark with 120 durable card/substitution events, explicit first-half transition, and recovery assertions for all 121 events and 123 command IDs. Reports pre-checkpoint journal bytes separately from total bytes. Commit d134601.
- This is accelerated synthetic load, not a real-time endurance or hardware certification. The GitHub file update succeeded; runtime results remain unverified. Next: measure growth and latency before changing journal format. No new dependencies.

## 2026-11-21 — Journal lookup allocation reduction
- Use reverse search without copying the entire parsed journal array on commit or filtering it on recovery (4d638100). Complete-line parsing and torn-tail detection are unchanged; Node 22 supports findLast.
- No on-disk format change or new dependency. Runtime verification pending; full journal parsing and full-state checkpoint growth remain unresolved. Do not infer a measured performance improvement from this change.
