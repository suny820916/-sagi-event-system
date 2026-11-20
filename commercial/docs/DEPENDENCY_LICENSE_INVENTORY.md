# Dependency & License Inventory

Status: initial inventory. This file must be expanded before any commercial release.

## New commercial core

### Node.js built-in modules
Used by:
- `commercial/core/file-store.mjs`
- `commercial/tests/match-core-selftest.mjs`

Modules currently used:
- node:fs/promises
- node:path
- node:assert/strict
- node:os

Third-party package dependency: **none**.

## Existing SAGI broadcast baseline

### Browser control / graphics
The verified V4.31 control and graphics files are primarily embedded HTML/CSS/JavaScript. A full asset/license scan is still required for any copied fonts, icons, images, libraries or code fragments before commercial packaging.

### PowerShell
The current launcher uses Windows PowerShell / .NET APIs supplied by the operating system. This is a platform/runtime dependency, not a bundled open-source package.

### vMix
SAGI integrates with the locally installed vMix HTTP API. vMix is third-party proprietary software and is not to be redistributed as part of SAGI unless separately licensed. Commercial documentation must state the supported vMix requirements.

### Playwright
The existing GitHub CI workflow installs Playwright for browser self-tests. It is a development/test dependency, not currently part of the SAGI runtime distribution. Its license notice must still be retained as required in development/distribution materials if artifacts ever bundle it.

## Release rule

No new third-party runtime dependency may enter SAGI Commercial without recording:

- package/project name
- version
- source
- license
- redistribution obligations
- whether source disclosure is required
- whether notices are required
- whether it is runtime, build-time or test-only

AGPL/GPL or custom restrictive licenses require explicit review before use in a closed commercial build.
