# Architecture

## Design principle

The match must continue even when the internet disappears.

```
SAGI Cloud
  |
  | optional sync / licensing / updates
  v
SAGI Local Engine <----> SAGI Control (phone on LAN)
  |
  +----> SAGI Broadcast Desktop
  |
  +----> vMix Adapter
  |
  +----> Local State Store
  |
  +----> Replay / Director Workflow Engine
```

## Local Engine

The Local Engine is the source of truth during a match.

Responsibilities:

- match state
- clock state
- score state
- cards / substitutions / penalties
- roster and player media
- event journal
- idempotent command handling
- phone / desktop synchronization
- vMix command queue
- replay workflow state
- crash recovery checkpoints

## Offline-first rule

Internet-dependent services must never sit in the critical event path.

Critical path:

phone/desktop command -> local engine -> state commit -> broadcast graphics/vMix action

Cloud sync happens after the local commit.

## Reliability rules

- Every event has a unique event_id.
- Commands are idempotent.
- State changes are journaled before external vMix actions.
- vMix failures are retried without duplicating the football event.
- Last-known match state is restored after restart.
- Phone reconnect retrieves authoritative state from Local Engine.
- The system can run for a full match without cloud access.
- A failed update must be automatically roll-backable.

## Commercial cloud

Cloud responsibilities are intentionally non-critical:

- accounts
- device licenses
- subscription status
- templates
- team library
- backup
- release manifest
- diagnostics upload
- telemetry with explicit privacy controls

Cloud outage must not stop an active match.
