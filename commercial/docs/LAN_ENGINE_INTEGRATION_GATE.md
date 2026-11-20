# LAN → Local Engine integration gate (2026-11-20)

Status: **BLOCKED — not live-certified**. This document records verified source-level observations, not a passing test.

## Confirmed from commercial branch source

- `commercial/lan/lan-gateway.mjs` accepts an injected `getState` and `submitCommand`; it does **not** instantiate the durable Local Engine or vMix adapter.
- `commercial/lan/lan-command-selftest.mjs` uses an **in-memory** revision counter and Map for deduplication. Its duplicate-goal test does not prove persistence or recovery after restart.
- The LAN command allowlist is `GOAL`, `SCORE_CORRECTION`, `YELLOW_CARD`, `RED_CARD`, `SUBSTITUTION`, `PENALTY`, `START_CLOCK`, `PAUSE_CLOCK`, `RESUME_CLOCK`, `END_MATCH`. Canonical engine names and payload shapes must be compared before wiring.
- `LanPairing` keeps active sessions and pending codes in memory; restart invalidates them. Bearer tokens are currently transmitted over HTTP on a local interface.
- The gateway does not provide a phone UI, desktop approval UI, vMix readback, or a durable vMix cue outbox.
- A successful HTTP 200 from the command callback is **not** proof that vMix changed its on-air output.

## Integration acceptance tests (not yet run)

1. Start a durable Local Engine in a temporary directory, attach the LAN Gateway through an explicit narrow adapter, pair a simulated phone.
2. Send GOAL with a stable commandId; assert the state revision and score change exactly once.
3. Repeat the same commandId after HTTP reconnect and after a **full engine process restart**; assert no duplicate goal and identical stored result.
4. Send a stale expectedRevision with a new commandId; assert 409 and no event journal append.
5. Interrupt journal writing and recover; assert either complete commit or explicit fail-closed recovery, never partial score.
6. Disconnect WAN while retaining LAN; assert all match commands continue without DNS, CDN, GitHub or Render.
7. Stop vMix; assert match state commands still commit, cue delivery is explicitly degraded, and no blind replay of ambiguous side effects.
8. Reconnect vMix and compare active/preview inputs to the requested cue; do not label the transition confirmed before readback.
9. Test Windows + Safari/Android browsers for pairing, refresh, idle timeout, phone sleep/wake, and local firewall behavior.
10. Run an endurance and license/asset inventory gate before any Stable tag.

## Release policy

Do not merge into `main` or advertise LAN mobile control as working until the above tests have evidence (test command, logs, OS, vMix version and commit SHA). Keep all new code on `commercial-v1.0`.
