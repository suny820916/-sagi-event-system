# SAGI LOCAL CONTROL V1 — Read-only diagnostics starter

## Run on Windows

1. Open PowerShell in the downloaded/extracted project folder.
2. Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\sagi-local-control\SAGI-Diagnostics.ps1
```

Optional custom endpoints:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\sagi-local-control\SAGI-Diagnostics.ps1 -VmixBaseUrl http://127.0.0.1:8088 -BridgeHealthUrl http://127.0.0.1:8787/health
```

Reports are written to `Documents\SAGI-Diagnostics` as JSON and Markdown.

## Scope

This script is deliberately read-only. It checks Windows/PowerShell, the local vMix process, vMix Web Controller API reachability, the configured SAGI Bridge health URL, and default local TCP ports. It does not alter a match, click the desktop, send vMix commands, expose ports, or contact external services.

## Important

- Enable vMix Web Controller locally before expecting the API probe to pass.
- Confirm the configured port in vMix; 8088 is only the default assumption.
- Bridge health URL/port may differ by installed SAGI build; pass the actual local URL.
- A passing HTTP probe does not certify the visible Browser/Overlay output. Human visual acceptance is still required.
- This is not a remote-control channel. ChatGPT in a browser cannot directly access your Windows desktop or localhost.
- Do not expose the vMix API or this diagnostic script to the public internet.
