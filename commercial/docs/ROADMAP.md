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

## 2026-11-21 — Streaming journal validation
- Recovery and locked commits now stream UTF-8 journal records and retain only the latest state commit, rather than retaining every historical full-state object. Complete-line JSON validation and torn-tail latch remain; export still uses the existing full-history reader. Commit c0ba5a9.
- Extended benchmark with multi-chunk size assertion and malformed complete record rejection (96a2ada). Existing recovery assertions cover retained Chinese names indirectly via state hydration; dedicated UTF-8 boundary test remains open.
- No format or dependency change. Runtime/CI not yet verified. This reduces retained scan memory, not disk growth or total scan work; largest individual record still determines memory requirements. Measure latency and memory before release.

## 2026-11-21 — Compact durable clock records
- Clock-only writes now append CLOCK_CHECKPOINT records containing fixture ID, revision and elapsed seconds, rather than duplicating retained history. The streaming reader applies them to the preceding full STATE_COMMIT; older full-state checkpoint records remain readable. Export suppresses internal checkpoint records. Commits d2c29c3, 00dc2c1.
- Added benchmark growth budget (240 compact records below 61,440 bytes) and wrong-fixture rejection. Runtime/CI not yet verified; no measured speedup claimed. Full-state command records and full journal scans still grow. No new dependencies.
- **Format compatibility gate:** older readers do not understand compact records and can recover a stale clock. Do not downgrade against a live data directory; require a verified backup/restore or explicit compatible migration before commercial rollback. Test mixed-format replay, torn compact records, actual Windows durability and rollback before release.

## 2026-11-21 — Journal-only clock checkpoint writes
- After fsynced compact checkpoints, skip full snapshot backup and replacement (a2a7710). Full command commits continue to refresh snapshots. Recovery must use the journal; snapshot-only export or downgrade may omit recent elapsed time.
- Benchmark now asserts unchanged snapshot bytes and tests torn compact tail recovery plus mutation refusal (abda263). Runtime/CI not yet verified. No new dependencies. Full scans remain a latency risk; verify snapshot-only consumers and require journal-inclusive backups before release.

## 2026-11-21 — Validated journal head cache
- Under the existing writer lock, reuse a private cloned journal head when file identity, size and modification/change timestamps match the last full scan or durable append. Startup recovery still scans all records. Other cooperating writers invalidate the cache. No on-disk format or dependency change. Commit 714582a.
- Added regression cases for independent writers, stale checkpoints, caller mutation of returned state and externally appended invalid checkpoints (5008d47). Existing 240-checkpoint benchmark remains the measurement gate.
- Verification: source commits succeeded; direct clone failed DNS resolution and combined status / PR-filtered workflow lookup returned no results. Runtime and CI are unverified, not failed or passed. No measured latency improvement claimed.
- Cache assumes exclusive cooperating writers and ordinary local filesystem metadata semantics; it is not a cryptographic integrity check or defense against arbitrary concurrent external file edits. Validate metadata behavior on actual Windows NTFS, cross-process recovery, scan fallback and endurance before release. Do not use network/shared data directories without separate support and testing.

## 2026-11-21 — Journal scan failure recovery gate
- Locked writes now invalidate the journal cache and latch JOURNAL_SCAN_REQUIRES_RECOVERY when the authoritative scan throws (33391c7). This prevents automatic resumption of mutations after a transient or corrupt journal read; restart and validated recovery are required.
- Extended storage benchmark to assert the latch, refusal after external restoration of valid bytes, and successful readback on a fresh store (c307c5b). Production operators must not overwrite live journals; restoration in this test is a controlled fixture only.
- Verification: source updates accepted by GitHub. Direct clone still fails DNS; combined status for prior head returned no statuses. Runtime/CI not verified. No new dependency or format changes. Next: verify the accumulated suite and actual Windows recovery before further persistence changes; continue LAN/vMix integration independently.

## 2026-11-21 — Established journal disappearance protection
- Refuse mutation when a previously cached authoritative journal disappears, or when an observed journal vanishes before stream open. Do not silently recreate history. Commit c9d569f.
- Added regression for deletion after recovery, no recreation, and restart-required latch even after fixture restoration (4ae7bad).
- Runtime/CI verification pending. This guard is not a persistent missing-journal sentinel across process restarts; snapshot-only fallback on a fresh instance remains a release risk. No format or dependency changes.
- Phase 4 acceptance addition: retain V4.32 one-click full introduction (competition, matchup, both lineups/formations, return to program), plus individually triggered goal/player photo, yellow/red card and substitution sequences. Require cancellation and return-to-program validation; these are requirements, not implemented features.

## 2026-11-21 — Restart missing-journal gate
- Fresh stores now reject missing authoritative journals when either primary or backup snapshot exists; both load and mutation paths fail closed. Commits 10cf800, b52715a (regression).
- Compatibility: snapshot-only imports/restores are no longer accepted implicitly. Restore a verified journal-inclusive backup or provide an explicit migration procedure. Empty/replaced journals and loss of all artifacts remain separate risks.
- Verification: GitHub source writes succeeded; Node 22 is available but direct git access failed DNS resolution. Runtime and Windows CI results remain unverified. No new dependencies or on-disk format change. Prioritize executable test retrieval and LAN/vMix integration before more storage micro-optimizations.

## 2026-11-21 — Recovery regression CI triage
- Core run 44906947049 failed on both Windows and Ubuntu at snapshot-failure-selftest (HTTP 503 versus 200); six preceding runtime steps passed on each platform. Clock and storage benchmark were skipped. LAN run 44906926002 passed for 10cf800.
- The test created a backup-path directory before the first journal commit, correctly triggering the new missing-journal guard. Removed that artificial backup while retaining the temporary snapshot directory fault injection (3f1e252). Production recovery guard unchanged.
- Re-run core matrix and inspect benchmark before further persistence changes. Actual Windows/vMix and endurance certification remain open. No new runtime dependencies.

## 2026-11-21 — Empty journal recovery gate
- Existing but empty or state-less journals now fail closed instead of falling back to potentially stale snapshots. Commit 9b26445.
- Added regression cases for zero-byte, whitespace-only and unknown-record-only journals, including refusal to append and preservation of evidence (916a8f1).
- No format or dependency change. Existing empty journal files require explicit recovery, never automatic reset. A valid but truncated history ending on an earlier complete commit remains an open integrity risk.
- Verification: GitHub writes succeeded. Commit workflow lookup returned no runs (connector filters to PR-triggered runs); no new runtime PASS asserted. Core matrix re-verification remains pending.

## 2026-11-22 — Complete journal tail loss detection
- Full journal scans now reject an otherwise valid earlier journal head when a readable snapshot for the same fixture has a greater revision (9cc9d8a). Added regression for clean truncation, mutation refusal and evidence preservation (c2a2c5d).
- This is a conservative recovery gate, not a cryptographic integrity check. Loss of compact clock-only records, loss of all newer artifacts, or malicious snapshot modification are not covered. No format or runtime dependency changes; main untouched.
- Runtime and Windows/Linux CI verification pending. Prioritize executable matrix results, real LAN/vMix integration and endurance rather than further storage changes until tests are green.

## 2026-11-22 — LAN Host regression repair
- Source review found padded decimal Host ports could pass numeric comparison despite the existing negative regression. Compare the raw port string with the actual listening port's canonical decimal spelling (412c0fb).
- Existing lan-command-selftest already covers this case; no test weakening or dependency changes. Runtime/CI verification pending. This does not certify phone integration, TLS, or live vMix operation.

## 2026-11-22 — Offline presentation plan prototype
- Added pure, dependency-free Phase 4 planner for V4.32 one-click introduction (competition, matchup, home and away lineup, explicit return to program), plus independent goal/player, yellow/red card and substitution plans. Default introduction duration 24 seconds. Commits dec81f1, d36ab9f (self-test).
- Plans are immutable, require a cue ID and explicit return input; they do not execute vMix commands, render graphics, persist cue state or guarantee idempotent delivery. Duration and graphics are provisional until V4.32 visual parity is verified.
- Self-test source covers order, duration, return target, unsupported types and immutability; execution/CI pending. Next: connect to a serialized cancellable cue executor, validated input discovery and durable event IDs; reconcile uncertain vMix effects without blind retry. Keep manual program override authoritative. Main unchanged; no new dependencies.

## 2026-11-22 — Serialized presentation executor prototype
- Added cancellable single-active-cue executor with bounded in-memory duplicate suppression, explicit confirmed-output adapter contract and manual recovery gate after cancellation or ambiguous output (ede5192a). Cancellation deliberately does not issue an automatic return that could overwrite manual takeover.
- Added deterministic adapter self-test for sequence, duplicates, busy rejection, cancellation and uncertain output (b626cb35). Runtime and CI not verified in this run. No new dependencies; main untouched.
- Open: durable cue claims across restarts, trusted manual recovery UI, adapter timeout and readback, validated input mapping, actual graphics/vMix integration and CI wiring. In-flight adapters must honor abort; this prototype does not certify physical cancellation or on-air state.

## 2026-11-22 — Director automated verification gate
- Added `.github/workflows/commercial-director.yml` (2e4f24b) to execute the planner and executor self-tests on Windows and Ubuntu with Node 22 on commercial branch pushes. No runtime dependency or main change.
- CI execution results not yet observed; this is a test execution gate, not evidence of passing tests or actual graphics/vMix output. Next: inspect matrix results and wire a readback-confirmed vMix output adapter plus durable cue claims.

## 2026-11-22 — Persistent cue claim prototype
- Added exclusive local file cue claims using hashed validated IDs and fsync before output (9c5bf7a). Executor optionally reserves a cue before any output (9872e15); duplicate claims suppress replay across instances; storage errors block output.
- Extended matrix-covered executor self-test with concurrent duplicate claims, fresh instance duplicate and storage failure (9c3510f). Runtime results not yet verified.
- This is at-most-once claim admission, not confirmed delivery. Claims remain after failed or cancelled output; never automatically delete or replay them. Directory metadata durability under sudden power loss, storage loss, bounded retention, fixture-namespaced IDs, unresolved-cue operator reconciliation and global single-director ownership still require validation. Optional claim injection is not yet wired into the production shell. No new dependencies; main unchanged.

## 2026-11-22 — Confirmed presentation output boundary
- Added full-screen input switching adapter prototype with explicit graphic/program key allowlists, single Cut attempt and active-input readback deadline (829cf98). HTTP success alone cannot confirm output.
- Added executor integration regression for complete intro, wrong input, timeout, cancellation and no blind retry (ba52fd1); wired to Windows/Linux director CI (ee30751).
- Runtime and CI results not observed. Existing vMix transport binding, discovery-backed key mapping, bounded abort-aware transport, manual takeover detection, actual graphics and hardware verification remain pending. Readback confirms active input only, not rendered pixels or audio. This is not overlay support. No new dependencies; main untouched.

## 2026-11-22 — vMix presentation transport binding
- Propagated caller cancellation into bounded vMix fetch and disabled HTTP redirects (a7495b9).
- Added explicit graphic/program key binding to VMixAdapter, preflight discovery before each Cut, unique input-number validation and active-number-to-key readback (0d5a345).
- Added simulated HTTP end-to-end intro test, missing mapping and cancellation cases (791ae9f), wired into director matrix (3cd4ab7).
- Source commits accepted; runtime and CI results not verified. No new runtime dependencies; main untouched.
- Binding is not installed into a production shell. Manual takeover detection between steps, in-flight ambiguous effects, overall deadline including transport latency, actual vMix GUID compatibility and graphic assets remain release blockers. Full-screen cuts are not overlays. Next: verify matrix, add manual takeover safety and real Windows vMix acceptance.

## 2026-11-22 — Manual takeover guard
- Executor carries the expected previous program/graphic to each transition (628417d); output checks readback before switching (aac7871); vMix binding checks again immediately before Cut (0f0d7f2).
- Added simulated manual camera takeover during intro and goal holds; subsequent automatic cuts must stop and require manual recovery. Runtime/CI not verified in this run.
- This is observed-state protection, not atomic ownership: a manual cut between final read and command, or away-and-back during a hold, can evade detection. Actual vMix testing, operator cancellation and production shell integration remain required. No new dependencies; main untouched.

## 2026-11-22 — Director mapping identity guard
- Capture immutable graphic/program mapping at binding time and reject non-array program keys and duplicate input identities (b3a81ff).
- Add regression for caller configuration mutation and invalid program key type (8f9c858).
- Previous head c85d937 returned no PR-triggered workflow runs; this does not establish push CI status. New tests not executed in this run. No new dependencies; only commercial branch written.
- Remaining gates: actual resource migration, Windows/vMix acceptance, continuous manual ownership and production shell. Prioritize executable integration and CI evidence.

## 2026-11-22 — Shared director transition deadline
- Bound preflight, Cut transport and readback to a shared abort deadline (55705e3), with a maximum configured transition timeout of 30 seconds. Added stalled preflight regression requiring zero Cut calls (5c60908).
- This depends on the transport honoring AbortSignal; an already transmitted Cut may still take effect. Do not automatically retry ambiguous output. Runtime/CI verification pending; actual vMix and asset migration remain open. No new runtime dependencies; commercial branch only.

## 2026-11-22 — Reject ambiguous vMix discovery
- Reject duplicate valid input keys rather than silently deduplicating; reject inventories above 500 valid inputs rather than truncating. Commit 2668c5e.
- Director regression requires refusal before Cut (1cbc704); core status fixture now expects refusal and tests oversized inventories (c00e5ea).
- Runtime/CI verification pending. Invalid entries are still filtered, and global cross-instance director ownership is unresolved. No new dependencies; commercial branch only. Actual Windows/vMix and graphics integration remain release gates.

## 2026-11-22 — Shared director ownership prototype
- Added exclusive local filesystem ownership latch (42f01e8), optional executor admission guard (b58ecf4), and competing-instance/uncertain-output regression (c9b9a99).
- Successful completion releases ownership; cancellation or ambiguous output retains the latch across restart. No automatic age/PID reclamation. Busy admission does not consume the event ID.
- Recovery is currently manual: stop all director processes, reconcile actual vMix output and outstanding effects, then remove the latch before restarting. Never remove a live owner's latch. Existing in-memory recovery acknowledgement does not remove the file.
- Not production enforced: all cooperating instances must use the same protected local path per vMix endpoint; no production shell wiring, directory fsync/power-loss certification, cross-host exclusion or trusted operator recovery UI. Tests added to existing matrix-covered self-test, execution not yet verified. No new runtime dependencies; commercial branch only.

## 2026-11-22 — Guarded local director composition
- Added createLocalDirector factory combining vMix readback binding, local ownership latch and durable cue claims without optional bypass in the factory (2c8f157).
- Added simulated adapter integration regression for two instances, duplicate after re-creation and uncertain-output latch (5b5c1e2); wired to Windows/Linux matrix (6968672).
- Runtime/CI results not yet verified. This is a composition entry point, not a deployed desktop shell. Trusted shell must select one protected local data root per endpoint; no cross-host exclusion or automatic recovery. Actual graphics and hardware acceptance remain open. No new runtime dependencies; commercial branch only.

## 2026-11-22 — Read-only director recovery diagnostics
- Expose sanitized ownership presence (present/absent/unknown), active cue and blocked state in the guarded factory (4fd5d2d); add regression for live competing owner and restart after uncertain output (2f4417f).
- Diagnostics are advisory, not permission to delete a lock. A present latch may belong to a live instance. 中文现场处置：停止自动导演，人工确认 vMix 当前播出画面，排除未完成指令，停止所有相关进程，再由受信任维护人员按恢复规程处理锁；不得仅凭诊断结果解锁。比赛比分与计时应独立继续运行。
- Previous head ff919c8 returned no PR-filtered workflow runs; current tests not executed in this run. No new dependencies; commercial branch only. Desktop UI wiring and actual Windows/vMix acceptance remain pending.

## 2026-11-22 — Verified cross-platform CI baseline
- Verified push CI at b225188ded5df7f69b0dabaa760cb745ae220d87: director run 45006103383 and core run 45006103430 completed successfully. Both Windows and Ubuntu jobs passed, with all 5 director and 9 core runtime steps per platform successful (28 runtime step executions total).
- Evidence: https://github.com/suny820916/-sagi-event-system/actions/runs/45006103383 and https://github.com/suny820916/-sagi-event-system/actions/runs/45006103430 . This supersedes earlier pending core/director CI notes for the tested revision only.
- LAN-specific matrix not established by these runs. Real vMix, physical phone LAN, WAN disconnection, production assets, long-duration Windows operation and installer/rollback remain separate release gates. No commercial release authorization or runtime dependency changes.

## 2026-11-22 — LAN session admission recheck
- Revalidate the paired token after asynchronous request body parsing and before dispatching a command (f885e619). A revoked or expired session cannot submit a command through a slow outstanding upload.
- Added deterministic revocation regression (e3bbb873), asserting HTTP 401 and unchanged accepted-command count. Runtime/CI not verified for this revision. No runtime dependencies; commercial branch only.
- Admission does not cancel a command already handed to the canonical engine. TLS, device scopes, real engine integration, mobile UI and physical LAN acceptance remain open.

## 2026-11-22 — Chinese local mobile score console prototype
- Added same-origin /mobile and /mobile.js assets with pairing, authoritative score readback, HOME/AWAY goal commands, revision checking and same-ID manual retry (44962f7, c330852).
- Added HTTP asset/CSP/origin and script syntax assertions to LAN command CI (ca19416).
- No external assets or runtime dependencies. Tokens and pending commands are memory-only; browser reload can lose an unresolved command ID, session expiry during ambiguity requires operator intervention, and no automatic polling or full event UI exists yet. Do not expose plaintext pairing on untrusted networks. Not a production phone console.
- CI execution and physical phone acceptance unverified for this revision. Next: durable client intent reconciliation, session re-pair flow, browser interaction tests, clock/cards/substitution/penalties and protected transport.

## 2026-11-22 — Phone reload intent recovery
- Persist unresolved goal intent in same-tab sessionStorage before network dispatch; never persist pairing tokens. Re-pair after reload, retain original command ID/revision, require matching fixture before retry, fail closed on unavailable/corrupt storage. Add bounded request timeout. Commit f160c06.
- Authoritative engine checks optional fixtureId inside serialized command queue before duplicate/revision processing (f544d86); backward compatibility retained for older clients. Require unique fixture IDs in production. Added wrong-fixture/restart integration regression (a1729d8), and served-script simulated lost-response/reload/retry regression (5d65e57).
- Executed a separate mocked DOM/storage/transport evaluation of the fetched committed browser script: PASS, one goal despite two identical requests across reload. Full Node LAN/core matrix and real Safari/Windows not verified this run.
- Limits: sessionStorage covers same-tab reload, not tab closure/storage clearing/origin changes. No trusted manual reconciliation UI for mismatched fixtures, no cross-tab intent coordination, no automatic polling. Plain HTTP remains experimental. No new runtime dependencies; commercial branch only.

## 2026-11-22 — Mobile automatic read-only resync
- Poll authoritative match state every two seconds while paired and idle; never automatically replay mutations. Hide stale score and disable goals on read failure; resume reads after reconnect, require re-pair after HTTP 401. Guard goals against snapshots older than five seconds (d2224d5).
- Extend mocked browser regression to cover external score changes, offline/reconnect, expired session and no mutation replay (fb81caa).
- Runtime and CI execution not verified in this run. Background browser timer throttling, physical Safari, encrypted transport, clock/cards/substitution/penalty UI and production Windows integration remain release gates. No new runtime dependencies; commercial branch only.

## 2026-11-23 — Mobile stale retry and score validation
- Require fresh authoritative state for manual retries as well as new goals; invalidate freshness on pageshow and reject negative/noninteger scores or revisions (6975498). Extend served-script regression (5a59268).
- Executed fetched committed browser script with mocked DOM, storage, transport and timeout signal: PASS for lost response, pageshow stale retry refusal, same-ID retry deduplication and negative score rejection. Full Node LAN suite and Windows/Linux CI not verified this run; actual Safari lifecycle and timeout behavior not certified.
- No runtime dependencies; commercial branch only. Next: locate canonical clock/event schema and add typed mobile controls without weakening fixture/revision/intent checks. Physical LAN, protected transport and cross-tab coordination remain open.

## 2026-11-23 — Typed mobile cards and substitution
- Located canonical command definitions in commercial/core/match-core.mjs; mobile UI now submits YELLOW, RED and SUB using canonical side and player/off/on number fields (259faae). Existing GOAL intent compatibility preserved.
- Require numeric player numbers and distinct substitution numbers; keep fixture, revision, same-ID retry and sessionStorage protection for these actions. Added served-script regression (95f9f5c).
- Executed isolated proposed browser script with mocked DOM/storage/transport: PASS for missing number refusal, lost red-card response, reload/same-ID deduplication and substitution payload. Full Node CI and physical Safari/Windows/vMix not executed this run.
- Limits: numbers only, not roster-backed player identity; no actual graphic confirmation. Clock SET_CLOCK uses absolute elapsedSeconds and needs a separate atomic current-clock control to avoid rewinding during network delay. Penalty lifecycle, desktop integration and secure LAN remain open. No new runtime dependencies; commercial branch only.

## 2026-11-23 — Authoritative relative clock control
- Added SET_CLOCK_RUNNING, preserving server-observed elapsed seconds at serialized command execution, rejecting client elapsedSeconds and starts outside active playing periods (099155e). Local Engine explicitly applies clock transitions including recovery acknowledgment (e22cb05); LAN allowlist admits the command (b66d5f7).
- Added integration regression for delayed pause at 17 seconds, duplicate pause and persisted restart state, plus invalid PRE start (15fd450). Runtime/CI not executed this run. No new dependencies; commercial branch only.
- Existing absolute SET_CLOCK is unchanged for compatibility. Same-running new commands may reset fractional seconds; transition persistence latency and recovery UX require further review. Phone UI is not yet wired to this command. Next: verify integration CI, add typed start/pause and period display, and keep absolute corrections separate from routine phone control.

## 2026-11-23 — Mobile authoritative clock controls
- Added Chinese start/pause buttons and server clock/period display, with active-period guard and separate typed SET_CLOCK_RUNNING intent (8c4f440). Pending clock intent survives reload with same ID and no client elapsedSeconds or side.
- Extended served page regression for PRE guard, 1H display, lost start response, reload retry and pause (043665b). Isolated browser-script regression executed successfully with mock DOM/storage/transport, deterministic random bytes and timeout signal stubbed; syntax compilation passed. Full Node HTTP suite, engine integration CI and Safari/Windows/vMix remain unverified this run.
- No dependencies added; commercial branch only. Display uses server snapshots (2s polling), not frame-accurate broadcast timing. Next: verify canonical engine clock CI and integrate penalty controls, secure LAN and desktop approval.

## 2026-11-23 — Mobile penalty attempt controls
- Added separate Chinese shootout score and four scored/missed controls, enabled only during an active unfinished PEN state, with existing fixture/revision and persisted same-ID intent protection (bb21c60). Extended served-script regression (476f0ea).
- Executed fetched committed browser script regression with mocked DOM/storage/transport, deterministic random bytes and stub timeout: PASS (including previous clock/cards tests, penalty lost response/reload/retry, missed attempt, unchanged regular score and finished-state UI guard). Full HTTP/Node CI and actual Safari/Windows/vMix not verified this run.
- Important: canonical core currently permits PENALTY_ATTEMPT to implicitly start/reopen a shootout; UI guard is not a server authorization boundary. Before release, enforce authoritative lifecycle in serialized engine with same-ID duplicates checked first and verify compatibility. Start/finish controls, per-attempt dots, turn/order rules, undo, roster, actual graphics and protected LAN remain open. No new dependencies; commercial branch only.

## 2026-11-23 — Authoritative penalty lifecycle
- Core now refuses attempts and finish outside an explicitly started, unfinished PEN period; repeated start under a new ID and reopening after FT are refused. Existing duplicate IDs are resolved before lifecycle validation (796ef3a).
- Added LAN/engine restart regression for invalid attempts, explicit start, scored/missed attempts, finish, post-restart duplicate and unchanged regular score (b9a3ce6).
- Executed isolated proposed core code with JavaScript evaluator: PASS for lifecycle negatives, scored/missed, duplicate after finish and independent scores. Full HTTP integration and CI not executed this run. Check compatibility with existing core test fixtures and operator workflows that previously started penalties after FT; explicit start must precede final FT. General SET_PERIOD/FULL_TIME transitions, turn rules, undo, penalty dots and actual vMix graphics remain open. No new dependencies; commercial branch only.

## 2026-11-23 — Mobile penalty history display
- Render authoritative HOME/AWAY attempt history as numbered scored/missed circles with no five-round truncation (f538b36). Hide inconsistent history rather than inventing dots; clear history on failed reads.
- Extend served-script regression for deduplicated attempts, seventh round, inconsistent history and reconnect (34746fc). Execution and CI not verified this run. No new dependencies; commercial branch only.
- Undo, explicit start/finish operator UI, desktop/vMix graphics, real Safari and end-to-end verification remain open. The display alone does not enforce turn order or certify shootout rules.

## 2026-11-23 — Targeted penalty undo core
- Add UNDO_PENALTY_ATTEMPT for an explicitly identified latest active shootout attempt only; append compensating event without deleting audit history, adjust only shootout score, reject stale target and finished shootout. Same command ID remains deduplicated after hydration (bcd37c9, 43bc815).
- Add isolated regression (f6c0010) and Windows/Linux CI workflow (a01eb1d). Executed isolated fetched core with JavaScript evaluator: PASS for missed/scored undo, wrong target, serialized hydration duplicate, unchanged regular score, audit history and finished guard. Final error-code rename is source-only verified. Node workflow execution and actual durable restart/HTTP integration not yet verified.
- Undo is not exposed through LAN allowlist or operator UI yet. Next: integrate target-aware UI, HTTP restart regression and vMix state readback; ensure downstream consumers handle compensating events rather than replaying prior attempts. No new runtime dependencies; commercial branch only.

## 2026-11-23 — Mobile targeted penalty undo
- Admit UNDO_PENALTY_ATTEMPT in paired LAN command allowlist (6e6ef37); expose Chinese undo button with authoritative latest attempt ID and side/outcome preview, reject inconsistent or duplicate-ID history, require fresh active shootout state, persist same-ID intent across reload (dad12bb0).
- Extend served-script regression for lost undo response, reload/retry, unchanged regular score, shortened history and finished-state guard (9777481).
- Executed fetched committed browser script with mocked DOM/storage/transport and deterministic crypto/timeout stubs: PASS including previous regression cases. Actual HTTP gateway/engine durable restart, CI, physical Safari and vMix graphics remain unverified. No new runtime dependencies; commercial branch only.
- Next: real LAN-to-engine undo integration including stale target and durable restart; vMix consumers must handle compensating events and render authoritative history. No production certification.

## 2026-11-23 — Durable LAN penalty undo regression
- Extended actual HTTP gateway/engine integration test with stale attempt rejection, missed-attempt undo, full engine/gateway shutdown and re-pair, same-ID deduplication, scored-attempt undo and second restart. Assert authoritative penalty history and regular score separately (2a04666).
- Reviewed gateway allowlist, bridge error mapping and engine invalid-command mapping against the test. Runtime execution and push CI remain unverified in this run; no claim of restart certification. No dependencies or stable branch changes.
- Next: execute integration matrix; verify desktop/vMix consumers use authoritative history after compensating events, not incremental score replay.

## 2026-11-23 — Penalty state consistency and integration CI
- Include ordered attempt identity, side and outcome in consistencyView, rather than only history count (d3358be). Equal totals/counts no longer mask divergent dots. Added regression (e0ac499); executed fetched core and regression in isolated JavaScript evaluator: PASS, including undo cases. This is not Node HTTP or physical three-device evidence.
- Added actual engine/LAN restart regression invocation to Windows/Linux penalty CI (07cfe44). Push CI result remains unverified. No new dependencies; commercial branch only.
- Next: verify CI, locate desktop/vMix state consumers and connect authoritative history rendering; fingerprint is not a deployed sync mechanism. Physical LAN and vMix acceptance remain open.

## 2026-11-23 — Cross-platform penalty regression CI hardening
- Commit `9707df5` updates `.github/workflows/commercial-penalty-undo.yml`: explicit read-only workflow permission, 12-minute per-job timeout, independent Windows/Linux matrix failures, Node syntax gates for core/LAN/mobile sources, reducer undo regression and durable HTTP restart regression.
- **Verification:** GitHub accepted the workflow update; this is not evidence that either OS job passed. Inspect Actions job conclusions and logs before closing the CI acceptance gate.
- **Release blockers:** Windows/vMix/Safari real hardware tests, authoritative vMix overlay readback, LAN bearer-token transport protection, and crash/power-loss endurance remain pending. No changes to main/V4.40 Stable.

## 2026-11-23 — Seven-round penalty LAN persistence regression
- Extended `commercial/lan/engine-lan-selftest.mjs` with 14 alternating home/away penalty attempts after undo, including scored/missed outcomes, chronological history checks, a real Local Engine + LAN gateway restart, score/revision verification and duplicate command retry after restart.
- Commit: `a02059d3` (commercial-v1.0 only). The existing `commercial-penalty-undo.yml` workflow includes this self-test on Windows and Ubuntu.
- **Verification:** source committed through GitHub API; this run did not execute Node or obtain a passing Actions check. Tests are added, not certified passed. Real vMix on-air readback, iPhone Safari, offline Windows endurance and commercial license audit remain open.

## 2026-11-23 — Late mobile penalty retries after full time
- Extended the real HTTP LAN→Local Engine restart integration test to replay **all 14** seventh-round-and-beyond penalty command IDs after `FINISH_PENALTIES` and restart, asserting every response is flagged duplicate, the canonical revision is unchanged, penalty history IDs/order/outcomes remain identical, and the shootout stays finished.
- Commit: `efd08d77` (`commercial/lan/engine-lan-selftest.mjs`). This is **test coverage only**, not a new production feature.
- **Verification:** GitHub contents API accepted the test commit; no Node test run or Windows/Linux CI success was observed in this run. Previous commit combined status query returned an empty status list, which is not a pass. The test must run successfully before closing this acceptance gate.
- **Still blocked for commercial release:** real vMix on-air readback, phone Safari LAN pairing and token security, Windows power-loss recovery, signed installer/rollback, full license audit and offline endurance certification. Keep `main` isolated.

## 2026-11-23 14:04 CST — Concurrent finalized penalty retry coverage
- Added a concurrent batch of all 14 previously accepted penalty command IDs after finalization and server restart in `commercial/lan/engine-lan-selftest.mjs` (commit `9070be0`). Each HTTP response must report a durable duplicate and the authoritative final state must remain unchanged.
- **Verification:** GitHub contents API accepted the test update. The local runner could not resolve `github.com` for a clone (`Could not resolve host: github.com`); Node execution and Windows/Linux CI result are **not verified**. Test added is not a test passed.
- **Open:** verify CI run, run Windows/Safari/vMix hardware integration, exercise real WAN loss and power interruption, and confirm display state reconciliation. No changes to main or V4.40 Stable.

## 2026-11-23 — Final-whistle event boundary
- Audited the reducer and found that a new GOAL, YELLOW, RED, SUB, HALF_TIME or FULL_TIME command could still mutate the match after period FT; delayed mobile messages could therefore alter the final score.
- Added a reducer-level FT guard for match events, preserving post-match MVP selection. Existing processed command IDs are checked before the guard, so exact historical retries remain idempotent.
- Extended penalty reducer self-test with rejected late events, unchanged revision and allowed post-match MVP.
- Commits: eef83f96, 92168885. **Validation pending:** GitHub accepted the commits, but Node test execution, CI and Windows/vMix hardware results have not been confirmed in this run.
- **Known remaining risk:** SET_PERIOD, SCORE_ADJUST and other administrative commands can still change a finished match; a deliberate authorized correction workflow and privilege model must be specified. Command ID reuse with different payloads is not yet fingerprint-checked. Do not advertise final-score immutability or commercial readiness.

## 2026-11-23 — Final-state administrative mutation guard
- Ordinary commands now reject SCORE_ADJUST, SET_PERIOD, clock changes and penalty lifecycle changes after FT. Previously only event commands were blocked, allowing a finalized result to be reopened or altered.
- Duplicate command ID detection still precedes the final-state guard, preserving delayed mobile retry idempotency. MVP, SET_SCOREBOARD and CLEAR_EVENT remain permitted for post-match presentation.
- Added regression assertions for rejected mutations, unchanged consistency view, delayed FINISH_PENALTIES retry, and permitted scoreboard presentation.
- Commits: 23443bf, bbcb796. **Verification:** GitHub accepted source and test updates; Node/CI and real Windows/vMix tests have not been confirmed in this run. This is not a production-certified result lock.
- **Remaining risks:** command-ID reuse with different payloads, administrator-authorized post-match corrections with audit trail, durable restart/physical power loss, full LAN/vMix state reconciliation, and license/installer validation.

## 2026-11-23 — Conflicting command-ID replay guard
- Added a persisted semantic fingerprint for newly accepted commands. A retry with the same ID and equivalent payload remains idempotent even if `createdAt` or `expectedRevision` changes; reusing that ID with a different payload now throws `COMMAND_ID_CONFLICT` rather than silently acknowledging the wrong operation.
- Added reducer regression covering hydration/restart-like serialization, legitimate retry, conflicting HOME/AWAY goal, and unchanged score.
- Commits: `166a697`, `7954cd3`. GitHub accepted the source/test changes; Node execution, CI and Windows hardware validation have **not** been confirmed in this run.
- **Migration caveat:** older persisted processed IDs lack fingerprints and retain legacy duplicate handling; do not claim retrospective conflict detection. Fingerprint storage grows with command count, and client error-code mapping plus durability/endurance tests are still required. No new third-party dependencies.

## 2026-11-23 — LAN duplicate-command conflict HTTP mapping
- Map reducer `COMMAND_ID_CONFLICT` to HTTP 409 with a stable error code, instead of generic 503. This distinguishes a reused command ID with changed payload from a transient gateway outage and prevents clients from blindly retrying a semantically conflicting command.
- Extended LAN command regression to verify 409 and no second command dispatch; this uses a simulated command handler, not the production Local Engine end-to-end.
- Commits: 1cb48b8, bc0270e. Node tests and GitHub CI not confirmed in this run: container DNS cannot resolve github.com. No main/V4.40 modifications or new dependencies.
- Open: verify CI and real engine HTTP conflict behavior; normalize error propagation from Local Engine; real iPhone Safari/vMix LAN tests, TLS/credential exposure, crash recovery, and commercial license audit remain release blockers.

## 2026-11-23 — Real LAN engine command-ID payload conflict regression
- Added real HTTP gateway → canonical Local Engine → durable store assertion for a reused penalty command ID with changed outcome after restart (`commercial/lan/engine-lan-selftest.mjs`, commit `68e506f`). Expected response: HTTP 409 `COMMAND_ID_CONFLICT`; state revision and penalty history must remain unchanged.
- This specifically closes a *test coverage gap*: earlier gateway conflict tests used a fake callback, and existing real-engine tests only checked identical retries. It is not evidence of a passing runtime test.
- **Verification pending:** execute Node integration test and Windows/Linux CI; check historical journal migration without fingerprints, vMix readback, Safari LAN pairing, power-loss recovery, and transport security before commercial release.

## 2026-11-23 — LAN state-read revocation boundary
- Rechecked paired-session authorization after asynchronous `/api/v1/lan/state` retrieval; a token revoked while the backend is waiting must receive HTTP 401 instead of the private match state.
- Added deterministic deferred-read regression test `commercial/lan/lan-state-revocation-selftest.mjs` and wired it into Windows/Linux LAN CI.
- Commits: `5efdaa7`, `2957983`, `a391103` (source, regression, CI).
- **Verification:** GitHub writes confirmed; Node execution and Actions PASS are not confirmed. This closes only one revocation race. Plaintext LAN bearer transport, real Safari/vMix integration, operator approval UI, Windows endurance, crash recovery and full dependency-license review remain release blockers.

## 2026-11-23 — In-flight LAN command revocation response boundary
- Revalidate paired session after asynchronous `submitCommand` resolves, before returning its result; a revoked token receives HTTP 401 instead of command result data.
- Added a deterministic deferred-command HTTP regression case verifying revocation during the in-flight command and distinguishing response suppression from mutation rollback.
- **Important:** a command admitted before revocation may already have committed; clients must re-pair and resynchronize authoritative state rather than retry with a new ID. This is not cancellation or exactly-once transport delivery.
- **Verification:** GitHub file updates accepted. Node execution, CI success, Windows/Safari LAN behavior, and vMix live verification have not been confirmed for this change.
- **Release blockers remain:** plaintext LAN bearer-token exposure, authenticated desktop pairing, physical Windows endurance and power-loss recovery, actual vMix read-back, complete dependency/license audit.

## 2026-11-23 — LAN revoked-session error confidentiality
- Fixed a response-boundary gap: an in-flight command that rejects after the phone session is revoked could previously disclose `REVISION_CONFLICT` and the current revision. The command catch path now checks session validity before returning error details. State-read failure also checks revocation before returning an error.
- Added a deterministic deferred-command regression test that revokes authorization while the canonical callback is pending and then rejects with a revision-bearing error. Expected response: 401 `UNAUTHORIZED`, no revision disclosure.
- Commits: `9d927e5` (gateway), `f2f0744` (regression test).
- **Verification:** source and test commits accepted by GitHub; no Node execution, Windows/Linux CI pass or real Safari/vMix session confirmed in this run. This is not a claim of end-to-end authorization or LAN transport security.
- **Release blockers:** plaintext LAN bearer token transport, trusted desktop pairing approval, Windows endurance/power loss, live vMix readback, license audit and full offline-first acceptance remain open. Keep main/V4.40 Stable untouched.

## 2026-11-23 — Revoked-session state-read failure regression
- Added a deterministic HTTP regression in `commercial/lan/lan-command-selftest.mjs` for a failed asynchronous state read while a phone session is revoked.
- Expected result: HTTP 401 with only `UNAUTHORIZED`, not a state-store failure or private match data.
- Commit: `8e5ecc5`. This covers an existing gateway behavior; it does not implement LAN encryption, physical approval, or vMix readback.
- **Verification pending:** the GitHub file update succeeded, but the runner cannot resolve `github.com` for cloning. Node execution, Windows/Linux CI status, Safari and vMix hardware acceptance remain unverified. Do not count the new regression as PASS.
- **Priority:** obtain executable CI evidence and complete end-to-end LAN engine/vMix and Windows endurance gates rather than treating isolated security tests as commercial readiness.

## 2026-11-24 — LAN state-read revocation success-path regression
- Added deterministic test for a successful asynchronous state read completing after paired-phone revocation. Expected HTTP 401 with no match revision or private payload. This complements the existing failing-read/revocation case.
- Commit: `ab72a8b` (`commercial/lan/lan-command-selftest.mjs`).
- **Verification:** GitHub file update succeeded; Node execution and CI PASS have not been established. The test does not prove protected transport or Windows/Safari compatibility.
- **Release blockers:** LAN bearer tokens remain plaintext over HTTP; canonical end-to-end mobile/vMix testing, Windows power-loss recovery, complete license audit and offline installer/rollback remain outstanding.

## 2026-11-24 — Reproducible release evidence gate
- Added `commercial/docs/RELEASE_EVIDENCE_GATE.md` (commit `4060b443`) with exact local Node commands, required Windows/iPhone/vMix offline and restart scenarios, no-duplicate-command criteria, vMix failure handling, license/SBOM review, and a dated evidence ledger template.
- This is an **acceptance specification**, not a production fix or a passing test. No CI, Node, Windows, iPhone Safari, physical power-loss or real vMix execution was performed as part of this documentation change.
- Release decision remains **NO-GO**. Prioritize running existing tests and recording reproducible evidence before further declaring feature completion. `main` and V4.40 Stable remain outside this work.

## 2026-11-24 — Local release evidence collection
- Added `commercial/tools/collect-release-evidence.mjs` (`bb5708b`) to run five documented LAN syntax/integration checks against the checked-out commercial branch, recording exact revision, platform, exit codes and SHA-256 hashes of command output without storing potentially sensitive raw logs.
- The script fails closed when Git metadata or the expected branch is absent and marks missing test files UNKNOWN. Evidence is written to `commercial/evidence/release-evidence-local.json` and is **not** a certification.
- **Verification:** GitHub accepted the new script; this run did not execute Node or Windows/vMix hardware tests. Validate the script on a real checkout and confirm its output before relying on the report. CI status remains unverified.
- **Next:** expand the runner to the complete CI test matrix, capture independently verified Windows/iPhone/vMix offline evidence, and ensure generated evidence is excluded from distributable bundles.

## 2026-11-24 — Evidence collector expanded (verification pending)
- Expanded `commercial/tools/collect-release-evidence.mjs` from five to eight checks: added LAN pairing, core snapshot failure and penalty undo self-tests. All three file paths were confirmed present on `commercial-v1.0` before editing.
- Collector now rejects changes to tracked files relative to the recorded HEAD, records `cleanTrackedTree`, and explicitly marks `scope: PARTIAL_AUTOMATED_CHECKS_ONLY` and `releaseDecision: NO-GO` even when this subset passes. Untracked files are not checked by this cleanliness gate.
- **Verification:** GitHub source update committed; no Node execution or CI PASS verified in this run. This collector is not the complete CI suite, and does not replace Windows/iPhone/vMix offline acceptance or license review.
- **Next:** execute the expanded collector on Windows and Linux with a clean checkout, retain evidence artifact and exit codes, then extend coverage to remaining CI checks and hardware tests.

## 2026-11-24 — Release evidence untracked-source gate
- Updated `commercial/tools/collect-release-evidence.mjs` to reject PASS if untracked non-ignored files exist under `commercial/`, since these can shadow imported modules or change test execution without appearing in `git diff HEAD`.
- Generated files under `commercial/evidence/` are excluded from this check so repeated evidence collection does not self-invalidate. The report records `cleanCommercialSources` and the count of untracked commercial files, but not their names.
- Commit `d931472a` changes the evidence gate only; it does **not** establish that any of the eight Node checks pass. GitHub write succeeded; Node execution and Windows/vMix/iPhone evidence remain pending.
- **Remaining limits:** untracked files outside `commercial/`, ignored source files, runtime environment contamination, and hardware/on-air behavior are not certified by this gate. Commercial release remains NO-GO.

## 2026-11-24 — CI failure triage and command conflict repair
- Inspected actual GitHub Actions job logs for run `45255010106`: both platforms failed `snapshot-failure-selftest.mjs` with `INVALID_PENALTY_LIFECYCLE` because the test omitted `START_PENALTIES`; added the explicit start command (`d78356e`).
- Inspected run `45255010178`: both platforms failed `engine-lan-selftest.mjs` because a reused command ID with changed payload returned HTTP 503 rather than required 409. Fixed Local Engine mapping of `COMMAND_ID_CONFLICT` to 409 (`430e149`) and preserved that specific conflict through the LAN bridge (`ca246de`).
- Evidence: earlier core tests passed until the failing step; commercial director workflow for `d78356e` passed. Newer CI runs are pending and must be checked before marking these repairs verified. No Windows vMix or phone hardware certification.
- Release remains **NO-GO**. Keep commercial changes isolated from `main` and V4.40 Stable.

## 2026-11-24 — Physical offline acceptance tracking
- Opened issue #35 (`https://github.com/suny820916/-sagi-event-system/issues/35`) as the single release-blocking checklist for Windows + iPhone Safari + real vMix WAN-disconnected acceptance, including lost-response idempotency, restart, penalty shootout, actual on-air readback, soak and installer/rollback evidence.
- Checked prior Actions runs `45255010106` and `45255010178`: both had failed Linux and Windows jobs; these are historical failures and do not establish current HEAD status. The commit-associated workflow query for `c26e02c` returned no PR-triggered runs, which is not evidence of a passing or absent push-triggered CI run.
- No Node or hardware test was executed in this update. No release gate has been cleared. Commercial release remains **NO-GO** and main/V4.40 Stable must remain untouched.

## 2026-11-24 — Release evidence syntax coverage expansion
- Expanded `commercial/tools/collect-release-evidence.mjs` from 8 to 12 checks, adding `node --check` for the canonical LAN bridge, LAN pairing implementation, engine/LAN integration test and penalty-undo regression test.
- Verified all four referenced files exist on `commercial-v1.0` via GitHub contents API. Commit: `2e2569b`.
- **Verification boundary:** GitHub accepted the source commit; these 12 checks have **not** been executed in this run. A passing syntax check is not a passing integration or Windows/vMix test. Keep commercial release **NO-GO** until CI evidence and real offline hardware acceptance are available.

## 2026-11-24 — Release evidence ignored-source and working-directory gate
- Updated `commercial/tools/collect-release-evidence.mjs` to refuse a PASS when executed outside the repository root or when ignored executable source files exist under `commercial/` (excluding generated evidence and dependency cache directories).
- Records `runningAtRoot` and `ignoredCommercialSourceCount` in the report. This closes an additional local-source shadowing route not covered by ordinary `git diff` and untracked-file checks.
- Commit: `08f757f1`. GitHub source write succeeded; Node execution and CI verification are still pending. The ignored-file scan intentionally does not inspect files outside `commercial/`, and ignored non-code assets remain outside this gate.
- Next: execute the 12-check runner on Windows and Linux, test the gate with deliberately ignored source fixtures, then prioritize actual Windows/iPhone/vMix offline acceptance. Commercial release remains NO-GO.

## 2026-11-24 — Windows automated baseline and final-state HTTP fix
- Exercised the 32 distinct Node commands defined by the four Commercial workflows on local Windows with Node v24.22.3, using files fetched at `ed06f7d`. Baseline: 31 PASS, one FAIL (the LAN–engine integration run, shared by two workflows). After finalization and restart, a fresh penalty command returned 503 instead of 400.
- `b19ce0a` maps the reducer's `MATCH_ALREADY_FINISHED` to HTTP 400. With the fix applied, all 32 commands passed, including the durable LAN restart, late duplicate retries, and command ID conflict checks. The storage benchmark checks simulated checkpoint correctness.
- Linux and Windows GitHub Actions (Node 22), the Git-dependent evidence collector, and physical offline acceptance were not verified by this run. No release checklist status changed. Release decision remains NO-GO. See issue #35 for the physical acceptance steps.

## 2026-11-24 — Unicode path release evidence regression
- Reproduced a false PASS: the collector counted zero ignored scripts when an ignored file had a Chinese filename, because the Git output ended in a quoting character after the extension.
- `f9f7a89` uses NUL-delimited Git paths for ignored and untracked files. In a disposable local Git fixture on Windows, Node v24.22.3 syntax validation passed. The collector returned exit 1 and counted one file in each of the ignored and untracked Chinese-path scenarios, then returned exit 0 on a clean fixture. All 12 embedded checks passed in each run; release decision remained NO-GO.
- The fixture used the fetched Commercial sources with local Git metadata. Full remote checkout, GitHub Actions on Windows and Ubuntu, and physical acceptance remain unverified. No release item was closed.

## 2026-11-25 — Preserve fixture mismatch through LAN
- The authoritative engine already rejected a stale fixture ID, but the LAN bridge reported it as a revision conflict. Preserve HTTP 409 and `FIXTURE_MISMATCH` while keeping revision and command-ID conflicts distinct.
- The expanded real HTTP integration assertion failed on `e50954d` and passed with the fix. All 32 distinct Node commands from four Commercial workflows passed on Windows with Node v24.22.3 using the Commercial source fixture. GitHub Actions Node 22 and physical Windows/iPhone/vMix acceptance remain unverified. No release checklist item was closed.

## 2026-11-25 — Shared Local Engine and mobile startup
- Added a runtime entry point for the future desktop host. It starts the authoritative engine on loopback, serves the existing mobile page on an explicitly selected interface, exposes operator-approved pairing in process, and closes both services together.
- The existing HTTP integration now exercises this runtime, including a busy LAN port followed by successful startup on the same match directory, mobile page delivery, pairing, durable restart, and duplicate commands. Windows Node v24.22.3: the existing 32 distinct workflow commands plus runtime syntax check passed across the suite and focused rerun. Windows/Ubuntu Actions and physical acceptance remain unverified.
- Desktop executable, QR presentation, protected mobile transport, vMix live cues and installer remain open. No release checklist item was closed.

## 2026-11-25 — Windows operator launch preview
- Added a Chinese Windows launch window that starts the shared runtime, displays the mobile address and approves pairing over an in-process child host pipe. The match directory is under the current Windows user's local app data.
- On Windows with Node v24.22.3, verified the PowerShell and Node syntax and exercised the child-host protocol, mobile page, pairing, goal, clean shutdown via pipe EOF, restart and duplicate goal without score change. Interactive window, physical phone/vMix tests, GitHub Actions and installer are still unverified.
- The preview requires a supplied Node runtime and exposes a typed mobile URL. QR rendering, packaged runtime, signing and protected LAN transport remain open. No release checklist item was closed.

## 2026-11-25 — Broadcast graphics direction preview
- Added a local browser preview for a compact scoreboard, goal score motion, event cards and extended shootout indicators. The graphics use SAGI-specific colors and Chinese presentation with a simulated match.
- Windows browser smoke test exercised all five scenes, seven penalty slots per team, current-kicker indication and local-file-only requests. Integration with authoritative state, transparent vMix output and physical verification remain open.

## 2026-11-26 — Authoritative transparent score output
- Added a loopback-only browser output with a per-runtime address, authoritative scoreboard visibility, clock and scores, embedded SAGI mark, and a side-colored GOAL animation for newly observed events. Initial loads and reconnects establish a fresh baseline. The desktop preview displays the browser input address.
- Windows HTTP integration and local Chrome verification passed with real engine commands, logo decoding, a committed goal, duplicate retry, and page reload. PowerShell launcher syntax passed. Actual vMix browser input, local team crest mapping, event and penalty overlays, and signing/packaging remain open.
