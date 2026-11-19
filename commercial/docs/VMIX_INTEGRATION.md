# vMix adapter — initial implementation

The adapter in `commercial/core/vmix-adapter.mjs` uses the vMix local HTTP API, with an explicit allowlist of functions. It has no external runtime dependencies.

## Safety contract

- vMix errors never modify the authoritative MatchState.
- HTTP timeouts/disconnections return a structured failure, not an unhandled exception.
- The adapter deliberately does not retry Cut, Fade, overlay or recording commands automatically: a timeout cannot prove whether vMix already executed the action.
- An HTTP 200 response only confirms API acceptance; it does not prove the intended on-air visual state.
- Only explicit configured IPv4/loopback endpoints are accepted. Configure vMix API on a trusted local network.
- No public internet endpoint or cloud relay is required.

## Still required before release

- Discover actual vMix inputs and reconcile them with configured roles.
- Read and parse vMix XML state for confirmation of on-air program and overlays.
- Implement a durable cue/outbox protocol and separate event-commit from side effects.
- Validate replay APIs and device-specific behavior against real vMix installations.
- Test disconnected/reconnected vMix during a full match.
- Add authentication/network isolation guidance for vMix's own API.
- Test Windows firewall and two-camera switching.

This module is an isolated adapter and is **not yet wired into the Local Engine**.
