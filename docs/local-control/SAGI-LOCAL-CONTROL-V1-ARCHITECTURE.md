# SAGI LOCAL CONTROL V1 — Architecture & Safety Contract

Status: design baseline only; not a production controller and not a V4.33 certification.
Branch: `feature/sagi-local-control-v1`
Stable baseline: V4.31.0 remains untouched.

## Product goal

Provide a Windows-local, LAN-first SAGI control/diagnostics service for vMix and the SAGI Bridge. The existing ChatGPT web page cannot directly access `localhost`, Windows processes, the desktop, or vMix APIs. A local bridge therefore does **not** grant this chat invisible remote-control access. The first usable workflow is: local bridge runs on the user's PC, creates a diagnostic/acceptance report, and the user explicitly attaches that report to the chat for analysis. Any later remote command relay requires a separately designed, explicit, authenticated channel and must never be assumed to exist.

## Phase 1 — Read-only diagnostics (first implementation target)

- Bind HTTP only to `127.0.0.1` by default. Do not bind to `0.0.0.0`.
- Generate a cryptographically random per-install pairing secret; store it with Windows user-only ACLs. Never print or upload it.
- Require an authenticated local session for every non-health endpoint; use CSRF protection/origin checks for browser UI actions.
- Read vMix state only through the configured local vMix Web Controller/API endpoint. Never expose the vMix API to the public internet.
- Read SAGI Bridge health/state using an explicitly configured local URL and strict timeout.
- Collect: OS/runtime version, bridge health, configured ports (redact secrets), vMix reachability/version if available, current input names/state, app build fingerprints, and timestamps.
- Provide diagnostics for three surfaces (phone control, desktop control, Browser/Overlay) only where each surface exposes a verifiable local health/fingerprint endpoint. Unknown is not pass.
- Export a timestamped JSON + human-readable Markdown report. Redact tokens, passwords, private URLs, and personally identifying data.

## Phase 2 — Acceptance runner

- Read-only checks first: current match identity, score, clock, cards, penalty state, revision/event sequence, output/browser fingerprints.
- Test fixtures must run against a disposable test match or explicit test mode. Never alter a live match by default.
- Every mutating test requires a visible local confirmation and a generated test-match ID.
- Cover score/penalty idempotency, undo/restore, new-match isolation, browser reload, bridge restart, stale cache detection, and cross-surface revision convergence.
- Record observed latency and per-surface revision. Do not label a test passed if one surface is unobservable.
- Produce evidence bundle; no automatic production certification.

## Phase 3 — Explicit operator actions (not enabled by this design document)

- Strict allowlist of named vMix actions only; no arbitrary URL, shell, PowerShell, file path, or process execution endpoint.
- Separate read and write permissions. Read-only is default.
- Destructive actions (stop output, close vMix, delete/reset match, change production camera) remain disabled or require an independent physical confirmation.
- Commands carry unique IDs, expiry, target match/session, expected revision, and idempotency key.
- Reject replayed, stale, cross-match, or out-of-order commands. Audit every accepted/rejected command locally.
- Emergency stop and manual vMix control always take precedence.

## Network and China-production constraints

- Core operation must work with no internet, no proxy, and LAN-only networking.
- No runtime dependency on GitHub Pages, Render, Google, jsDelivr, cdnjs, unpkg, or remote fonts/scripts.
- Updates are manual/maintenance-window only; never auto-update during a match.
- Cloud sync is optional and asynchronous; stale cloud state must never overwrite newer local state.
- No public tunnel, inbound router port-forward, or public vMix API.

## Packaging and acceptance

- Prefer a signed/inspectable PowerShell launcher and a small local service using an already available Windows runtime where practical; avoid requiring a new desktop application.
- Provide start/stop scripts, health check, port conflict diagnostics, log rotation, and uninstall/rollback instructions.
- Test on the actual Windows/vMix machine. CI and simulated tests cannot substitute for physical vMix/browser verification.
- Keep this work isolated from `main`, V4.31.0 stable, and V4.33 certification branches until separately reviewed and accepted.

## Initial acceptance gates

1. Service binds only to loopback.
2. No unauthenticated state or action endpoint.
3. vMix and Bridge unreachable -> clear degraded status, never false green.
4. Internet disabled -> diagnostics and report export still work.
5. Secret redaction test passes.
6. No arbitrary command execution surface exists.
7. Start/stop/restart and port conflict behavior are documented and tested.
8. Live match is not mutated by diagnostics.

