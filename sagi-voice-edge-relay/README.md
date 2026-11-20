# SAGI VOICE Edge Relay

Purpose: provide an overseas-only relay for SAGI VOICE PRO when mobile networks cannot directly reach `onrender.com`.

- Platform target: Cloudflare Workers
- Public hostname: Cloudflare-provided `*.workers.dev`
- No SAGI domestic server required
- No SAGI custom domain required
- Backend remains Render Singapore

Files:
- `worker.js`: restricted reverse proxy to SAGI Cloud `/health` and `/api/*`
- `wrangler.toml`: Workers deployment config

After an overseas relay URL is available, SAGI DOWN should be switched to that URL as the first cloud candidate, with Render as fallback.
