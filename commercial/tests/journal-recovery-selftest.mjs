import assert from "node:assert/strict";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { createInitialMatchState, applyCommand } from "../core/match-core.mjs";
import { FileMatchStore } from "../core/file-store.mjs";

const dir = await mkdtemp(path.join(os.tmpdir(), "sagi-recovery-"));
try {
  const store = new FileMatchStore(dir);
  let state = createInitialMatchState({
    fixtureId: "crash-test", home: "主队", away: "客队"
  });
  state = applyCommand(state, {
    commandId: "goal-1", type: "GOAL", side: "HOME"
  }).state;
  await store.commit(state, state.lastEvent);
  state = applyCommand(state, {
    commandId: "clock-1", type: "SET_CLOCK", elapsedSeconds: 777, running: true
  }).state;
  await store.commit(state);
  assert.equal((await store.readJournal()).length, 1);
  // Simulate stale/corrupted snapshot after a successful durable journal write.
  await writeFile(store.snapshotPath, "{corrupt");
  await writeFile(store.backupPath, "{corrupt");
  let recovered = await new FileMatchStore(dir).load();
  assert.equal(recovered.revision, 2);
  assert.equal(recovered.homeScore, 1);
  assert.equal(recovered.clock.elapsedSeconds, 777);
  assert.equal(applyCommand(recovered, {
    commandId: "goal-1", type: "GOAL", side: "HOME"
  }).duplicate, true);

  // A torn final journal record must not erase previously committed state.
  const before = await readFile(store.journalPath, "utf8");
  await writeFile(store.journalPath, before + '{"kind":"STATE_COMMIT"');
  recovered = await new FileMatchStore(dir).load();
  assert.equal(recovered.revision, 2);

  // A malformed complete record is not silently ignored.
  await writeFile(store.journalPath, before + "not-json\n");
  await assert.rejects(() => new FileMatchStore(dir).load(), SyntaxError);

  await writeFile(store.journalPath, before);
  const stale = applyCommand(
    createInitialMatchState({ fixtureId: "crash-test", home: "主队", away: "客队" }),
    { commandId: "other-goal", type: "GOAL", side: "HOME" }
  ).state;
  await assert.rejects(() => store.commit(stale, stale.lastEvent), /STALE_REVISION/);
  assert.equal((await store.readJournal()).length, 1);
  console.log("SAGI JOURNAL RECOVERY SELFTEST PASS");
} finally {
  await rm(dir, { recursive: true, force: true });
}
