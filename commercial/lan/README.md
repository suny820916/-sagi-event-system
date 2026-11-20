# LAN pairing prototype

Dependency-free local pairing primitive for SAGI Broadcast Commercial.

- Operator must explicitly approve code issuance on the desktop.
- One-time 6-digit code expires in 120 seconds by default.
- Five invalid attempts invalidate the pending code.
- Successful redemption creates a random 256-bit session token.
- Tokens are stored as SHA-256 digests in memory, not in plaintext.
- Session expiry and revocation are supported.
- Restart clears all pending pairings and sessions.

## Security limitations

This module is **not yet wired into the Local Engine HTTP server**. The caller MUST enforce that code issuance originates from a trusted local desktop UI, not a remotely supplied boolean. Rate-limit redemption by client IP as well as per-code, restrict LAN exposure to trusted networks, validate Host and Origin, and provide an authenticated revoke/session management UI. Without TLS, token interception is possible on hostile networks; do not expose on public Wi-Fi or WAN. Do not place pairing tokens in URLs or logs. Use secure local secret storage if persistent sessions are later added.

Test: `node commercial/lan/lan-pairing-selftest.mjs`
