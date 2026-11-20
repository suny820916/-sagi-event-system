# Verified V4.31.0 Reuse Inventory

This inventory is based on repository files and certified V4.31.x commits currently visible on the commercial branch baseline. V4.40 remains a separate active development line and must be re-inventoried when its stable code lands.

## Verified reusable assets

### `intro/v45-lan.html`
Current operator/control surface.

Verified capabilities include:

- authoritative matchday UI state
- score and period control
- event logging
- local recovery checkpoints
- state consistency checks
- page/network resume recovery
- goal / yellow / red / substitution events
- penalty controls
- graphics director
- replay stinger workflow
- shot-safety logic
- vMix input switching

Reusable approach: **yes**, but state mutation must be moved behind the commercial Local Engine so phone and desktop do not independently own critical state.

### `intro/vmix-v45-lan.html`
Current vMix Browser Input graphics surface.

Verified capabilities include:

- compact scorebug
- team colors and crests
- goal/event cards
- player photos
- cards/substitution graphics
- penalty graphics
- lineup / formation presentation
- match-state splashes
- SAGI Signature broadcast styling

Reusable approach: **yes**. Keep as presentation layer; remove business-critical state ownership.

### `intro/SAGI_VMIX_LAN_V48_STAGE_4310.bat`
Current Windows one-file launcher containing embedded PowerShell bridge + control + output payload.

Verified capabilities include:

- same-LAN phone control
- local vMix API bridge
- local match state file
- local match projects file
- health endpoint
- vMix input discovery/status
- update and rollback endpoints
- fallback embedded HTML/bridge payloads
- operation when vMix itself is offline

Reusable approach: **prototype/reference only**. Do not sell this architecture unchanged.

### Existing certification
- `.github/workflows/vmix-v4270-selftest.yml`
- `intro/tests/v4270-browser-selftest.mjs`
- `intro/tests/v4311-replay-hotfix-selftest.mjs`

Reusable approach: **yes**. Preserve the existing live-broadcast regression suite while commercial tests grow separately.

## Commercial blockers found

### 1. Online update dependency
The current bridge points update downloads to:

`https://suny820916.github.io/-sagi-event-system/intro`

Commercial runtime must not require GitHub Pages or any foreign CDN.

### 2. Wildcard CORS
Current local bridge returns:

`Access-Control-Allow-Origin: *`

Commercial build needs a local origin / session trust model so any device on the LAN cannot silently send privileged commands.

### 3. vMix command idempotency
`POST /api/vmix` executes received commands directly.

Commercial Local Engine needs command IDs, deduplication and replay-safe acknowledgement to prevent reconnect/retry from triggering duplicate external actions.

### 4. Match state persistence
Current state uses replace-style JSON snapshots.

The commercial core now introduces journal-first persistence plus recoverable snapshots. This must replace snapshot-only critical event handling.

### 5. Single-file BAT distribution
The BAT is useful as a recovery artifact but is not the final commercial delivery model.

Commercial target:

- signed Windows installer
- stable application directory
- explicit data directory
- service/process health monitoring
- update channel
- rollback
- diagnostics export
- version manifest

### 6. No commercial device/license layer
The current runtime has no customer/device entitlement layer.

This must be added without putting live match operation behind a fragile always-online license check.

## Migration rule

Do not rewrite graphics that are already proven stable merely for architectural purity.

Move responsibility in layers:

1. retain proven graphics
2. retain proven vMix commands
3. centralize MatchState and event ownership in Local Engine
4. wrap vMix actions with idempotent command handling
5. migrate phone/desktop clients to the engine API
6. only then replace launcher/distribution
