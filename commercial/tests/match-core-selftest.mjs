import assert from "node:assert/strict";
import { mkdtemp, rm } from "node:fs/promises";
import os from "node:os";
import path from "node:path";

import {
  applyCommand,
  consistencyView,
  createInitialMatchState,
  hydrateMatchState,
} from "../core/match-core.mjs";
import { FileMatchStore } from "../core/file-store.mjs";

let state = createInitialMatchState({
  fixtureId: "test-home-away-001",
  competition: "SAGI TEST",
  home: "主队",
  away: "客队",
});

assert.equal(state.homeScore, 0);
assert.equal(state.awayScore, 0);

const goal = {
  commandId: "cmd-goal-1",
  type: "GOAL",
  side: "HOME",
  player: { id: "7", name: "测试球员", number: "7" },
  at: "12:34",
  createdAt: "2026-11-19T12:34:00.000Z",
};

let result = applyCommand(state, goal);
state = result.state;
assert.equal(result.duplicate, false);
assert.equal(state.homeScore, 1);
assert.equal(state.sequence, 1);
assert.equal(state.eventLog.length, 1);
assert.equal(state.replayMarkers.length, 1);

const afterFirstGoal = consistencyView(state);
result = applyCommand(state, goal);
state = result.state;
assert.equal(result.duplicate, true, "duplicate command must be detected");
assert.equal(state.homeScore, 1, "duplicate goal must never increment score twice");
assert.equal(state.sequence, 1, "duplicate command must not create a new event");
assert.equal(consistencyView(state), afterFirstGoal, "duplicate must not mutate canonical state");

result = applyCommand(state, {
  commandId: "cmd-red-1",
  type: "RED",
  side: "AWAY",
  player: { id: "4", name: "客队4号", number: "4" },
  at: "44:10",
  createdAt: "2026-11-19T13:10:00.000Z",
});
state = result.state;
assert.equal(state.awayRedCards, 1);
assert.equal(state.replayMarkers.length, 2);

result = applyCommand(state, {
  commandId: "cmd-score-correct",
  type: "SCORE_ADJUST",
  side: "HOME",
  delta: -99,
  createdAt: "2026-11-19T13:11:00.000Z",
});
state = result.state;
assert.equal(state.homeScore, 0, "manual correction must never produce a negative score");

result = applyCommand(state, {
  commandId: "cmd-pen-start",
  type: "START_PENALTIES",
  createdAt: "2026-11-19T13:12:00.000Z",
});
state = result.state;
assert.equal(state.period, "PEN");

result = applyCommand(state, {
  commandId: "cmd-pen-home-1",
  type: "PENALTY_ATTEMPT",
  side: "HOME",
  outcome: "SCORED",
  player: { name: "主队点球手", number: "9" },
  createdAt: "2026-11-19T13:13:00.000Z",
});
state = result.state;
assert.equal(state.penalties.home, 1);
assert.equal(state.penalties.history.length, 1);

result = applyCommand(state, {
  commandId: "cmd-pen-away-1",
  type: "PENALTY_ATTEMPT",
  side: "AWAY",
  outcome: "MISSED",
  player: { name: "客队点球手", number: "10" },
  createdAt: "2026-11-19T13:14:00.000Z",
});
state = result.state;
assert.equal(state.penalties.away, 0);
assert.equal(state.penalties.history.length, 2);

assert.throws(
  () => applyCommand(state, { commandId: "bad-side", type: "GOAL", side: "LEFT" }),
  /INVALID_SIDE/
);

const hydrated = hydrateMatchState(JSON.parse(JSON.stringify(state)));
assert.equal(consistencyView(hydrated), consistencyView(state), "serialized state must recover identically");

const dir = await mkdtemp(path.join(os.tmpdir(), "sagi-commercial-"));
try {
  const store = new FileMatchStore(dir);
  const lastEvent = state.eventLog.at(-1);
  await store.commit(state, lastEvent);
  const loaded = await store.load();
  assert.equal(consistencyView(loaded), consistencyView(state), "snapshot recovery must preserve canonical state");

  const journal = await store.readJournal();
  assert.equal(journal.length, 1);
  assert.equal(journal[0].eventId, lastEvent.eventId);

  result = applyCommand(loaded, {
    commandId: "cmd-full-time",
    type: "FULL_TIME",
    createdAt: "2026-11-19T13:20:00.000Z",
  });
  await store.commit(result.state, result.event);

  const loadedAgain = await store.load();
  assert.equal(loadedAgain.period, "FT");
  assert.equal(loadedAgain.clock.running, false);
  assert.equal((await store.readJournal()).length, 2);
} finally {
  await rm(dir, { recursive: true, force: true });
}

console.log("SAGI COMMERCIAL CORE SELFTEST PASS", {
  revision: state.revision,
  sequence: state.sequence,
  events: state.eventLog.length,
  penalties: state.penalties.history.length,
  idempotency: "PASS",
  persistence: "PASS",
});
