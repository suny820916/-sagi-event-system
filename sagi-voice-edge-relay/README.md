# SAGI VOICE Edge Relay

Overseas-only relay for SAGI VOICE PRO when a mobile network cannot directly reach `onrender.com`.

- Platform: Cloudflare Workers
- Public hostname: Cloudflare-provided `*.workers.dev`
- No SAGI domestic server required
- No SAGI custom domain required
- Backend remains Render Singapore

## One-click deployment

[![Deploy to Cloudflare](https://deploy.workers.cloudflare.com/button)](https://deploy.workers.cloudflare.com/?url=https%3A%2F%2Fgithub.com%2Fsuny820916%2F-sagi-event-system%2Ftree%2Fmain%2Fsagi-voice-edge-relay)

Direct deployment URL:

https://deploy.workers.cloudflare.com/?url=https%3A%2F%2Fgithub.com%2Fsuny820916%2F-sagi-event-system%2Ftree%2Fmain%2Fsagi-voice-edge-relay

Cloudflare will clone this isolated Worker directory, create a Worker, configure Workers Builds, and provide a `workers.dev` URL.

## Files

- `worker.js`: restricted reverse proxy to SAGI Cloud `/health` and `/api/*`
- `wrangler.toml`: Workers deployment config

After deployment, use the generated `https://<name>.<account>.workers.dev` URL as the SAGI VOICE primary cloud endpoint; Render remains fallback.
