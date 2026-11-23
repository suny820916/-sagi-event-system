# Commercial V1.0 — Executable Release Evidence Gate

Status: **BLOCKED / NOT FOR SALE**. This document defines evidence to collect; it does not certify any test as passed.

## Evidence rules
- Every check needs a date, commit SHA, Windows build/Node version, exact command, exit code, log/artifact hash and operator.
- A committed test is **not** a passed test. A GitHub Actions run with no matching result is **UNKNOWN**, not PASS.
- Do not merge commercial changes into `main` or V4.40 Stable based on this checklist.
- Never include customer pairing tokens, license keys, personal data or LAN credentials in logs.

## Priority A — repeatable local checks
Run from the repository root on the exact `commercial-v1.0` SHA:

```powershell
git rev-parse HEAD
node --version
node --check commercial/lan/lan-gateway.mjs
node --check commercial/lan/lan-command-selftest.mjs
node commercial/lan/lan-command-selftest.mjs
node commercial/lan/engine-lan-selftest.mjs
node commercial/lan/lan-state-revocation-selftest.mjs
```

Record each command's exit code separately. Confirm the three self-test paths exist in the checked-out revision before executing. Run all other commercial self-tests listed in the CI workflow; do not substitute this subset for the full suite.

## Priority B — Windows LAN + vMix acceptance
1. Use a dedicated Windows test machine, an isolated Wi-Fi LAN and a real iPhone Safari client. Capture build, OS, vMix version, LAN subnet and test fixtures (without secrets).
2. Disconnect WAN while keeping LAN active. Exercise score, clock, goal, yellow/red card, substitution, penalty scored/missed/undo, replay and camera switching. Verify the authoritative engine and on-air vMix result separately; an HTTP 200 alone is insufficient.
3. Repeat the same command ID after lost HTTP response, refresh, phone reconnect and process restart. No duplicate goal/penalty/event or repeated vMix cue may occur.
4. Reuse an existing command ID with changed semantic payload; require HTTP 409 `COMMAND_ID_CONFLICT`, unchanged revision and event journal.
5. Revoke a phone session during a delayed state read and during a delayed command. Require HTTP 401 without private state or revision. An already committed command must be reconciled by reading authoritative state after re-pairing.
6. Disconnect or crash vMix during play. Engine scoring and journal must continue; cues must fail safely without blind side-effect retries. After reconnection, reconcile on-air state with the engine.
7. Perform 4-hour continuous test plus controlled kill/restart and physical power-loss recovery on disposable fixtures. Compare journal sequence, revision, scores, penalty history and hashes before/after.
8. Test signed Windows install, upgrade, rollback and offline startup without GitHub/Render/CDN access.

## Priority C — commercial/legal
- Generate a complete SBOM and review direct/transitive dependencies, bundled fonts, images, audio, icons, video assets and redistributed executables; preserve license texts and source-attribution obligations.
- Block unknown, incompatible or unreviewed redistribution licenses from release builds.
- Verify Chinese-first UI, local packaged assets, secure device authorization, backup/restore, diagnostic redaction and customer installation documentation.

## Evidence record template
| Date | Commit | Platform | Test/command | Result (PASS/FAIL/UNKNOWN) | Log/hash | Reviewer |
|---|---|---|---|---|---|---|
| Pending | Pending | Windows + iPhone + vMix | Full offline match | UNKNOWN | Pending | Pending |

Release decision: **NO-GO** until every mandatory gate has a reproducible PASS, a signed-off risk disposition, and an independently tested rollback.
