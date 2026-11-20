# SAGI BROADCAST Commercial V1.0

Commercial productization branch for SAGI Broadcast.

## Product position

SAGI Broadcast is a football-first live production operating system for small and medium event teams.

It is not a replacement for tournament registration platforms. Its core value is to automate live match direction around vMix:

- score and match clock
- goal / card / substitution events
- player graphics and lineup presentation
- penalty shootout graphics
- replay triggering
- multi-camera switching
- local mobile control
- event logging
- highlight markers
- post-match data export

## Commercial requirements

1. Match-critical functions must work offline on LAN.
2. Runtime must not depend on GitHub, Render, Google services, or foreign CDNs.
3. Stable releases must never be developed on directly.
4. New features flow through Dev -> Beta -> Stable.
5. Crash recovery, state consistency, logs, backups and rollback are mandatory.
6. Mobile control and desktop control must always share one authoritative match state.
7. vMix integration failure must degrade gracefully instead of blocking scoring.
8. All customer-facing UI defaults to Chinese.
9. Third-party dependencies require license review before commercial distribution.
10. Existing V4.40 stable workflow remains isolated from commercial refactoring.

## Initial product layers

- SAGI Local Engine
- SAGI Broadcast Desktop
- SAGI Control Mobile
- vMix Adapter
- Match State Store
- Replay / Director Workflow Engine
- License & Device Service
- Update / Rollback Service
- Diagnostics & Logs
- Cloud Sync (non-critical path)

Status: Phase 0 initialized.
