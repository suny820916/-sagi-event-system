# SAGI V4.34 GOAL PIPELINE — PREP CONTRACT

Status: **PREP ONLY — NOT IMPLEMENTED / NOT CERTIFIED**

This contract prepares V4.34 without changing the V4.33 production candidate or the certified V4.31.0 baseline.

## Event identity

A GOAL operation creates exactly one `eventId`. The same `eventId` must be referenced by:

- core score mutation
- `eventLog`
- GOAL animation payload
- `replayMarkers`
- automatic `highlight=true` candidate
- player goal statistics derived from `eventLog`

Retrying the same command must not create another score increment, event, replay marker, highlight or player goal.

## Commit order and SAFE MODE

Core state commits locally first: score → eventLog → derived data. Player photo, crest, transition and replay are non-critical effects.

If any non-critical effect fails, the committed score and event remain valid. Replay failure must return or remain on the configured live main input.

## Replay contract

The automatic replay path is local vMix API only:

1. mark a recent safe replay window;
2. associate exactly one replay marker with the GOAL `eventId`;
3. enter replay through SAGI/event transition;
4. play only the latest replay event;
5. stop replay events;
6. return to `MAIN_WIDE` or configured main input.

Cloud upload/highlight synchronization is asynchronous and never blocks the live path.

## Undo and recovery

Undo GOAL must remove/reverse the score mutation, linked automatic replay/highlight marker, and derived player goal statistic.

Refresh, phone reconnect, Bridge restart and Browser Input reload must rebuild from the durable local event/state model without replaying the GOAL animation or creating duplicate markers/statistics.

## Certification scenarios

The executable scenario list lives in `intro/tests/fixtures/v434-goal-pipeline-scenarios.json`.

Formal V4.34 implementation may begin only after V4.33 production certification. This prep branch is not a release branch.
