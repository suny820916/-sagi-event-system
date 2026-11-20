import assert from 'node:assert/strict';
import { mkdtemp, mkdir, rm, appendFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { FileMatchStore } from './file-store.mjs';
import { createLocalServer } from './local-server.mjs';

// Pure reducer regression: stopping periods and long shootout IDs.
const {createInitialMatchState, applyCommand} = await import('./match-core.mjs');
let fixture = createInitialMatchState({fixtureId:'period-test',home:'主队',away:'客队'});
const apply = (command) => { fixture = applyCommand(fixture, command).state; };
apply({commandId:'clock',type:'SET_CLOCK',running:true,elapsedSeconds:600});
apply({commandId:'half',type:'HALF_TIME'});
assert.equal(fixture.clock.running,false);
assert.equal(fixture.clock.elapsedSeconds,600);
const ids = new Set();
for(let i=0;i<205;i++){
  apply({commandId:'pen-'+i,type:'PENALTY_ATTEMPT',side:i%2?'HOME':'AWAY',outcome:'SCORED'});
  ids.add(fixture.penalties.history.at(-1).attemptId);
}
assert.equal(ids.size,205);
assert.equal(fixture.penalties.home+fixture.penalties.away,205);
apply({commandId:'clock-again',type:'SET_CLOCK',running:true,elapsedSeconds:600});
apply({commandId:'finish',type:'FINISH_PENALTIES'});
assert.equal(fixture.clock.running,false);

// A delayed retry must remain idempotent after the old 2048-ID window.
let longMatch = createInitialMatchState({fixtureId:'long-match',home:'主队',away:'客队'});
const oldGoal = {commandId:'first-goal',type:'GOAL',side:'HOME'};
longMatch = applyCommand(longMatch,oldGoal).state;
for(let i=0;i<2050;i++){
  longMatch = applyCommand(longMatch,{commandId:'toggle-'+i,type:'SET_SCOREBOARD',visible:i%2===0}).state;
}
const delayed = applyCommand(JSON.parse(JSON.stringify(longMatch)),oldGoal);
assert.equal(delayed.duplicate,true);
assert.equal(delayed.state.homeScore,1);
assert.equal(delayed.state.revision,longMatch.revision);

const dir = await mkdtemp(path.join(os.tmpdir(), 'sagi-snapshot-failure-'));
let engine;
const meta = { fixtureId: 'snapshot-failure', home: '主队', away: '客队' };
const command = { commandId: 'goal_snapshot_01', expectedRevision: 0, type: 'GOAL', side: 'HOME' };
async function send() {
  const result = await fetch('http://127.0.0.1:' + engine.address.port + '/api/v1/commands', {
    method: 'POST', headers: { authorization: 'Bearer ' + engine.token, 'content-type': 'application/json' },
    body: JSON.stringify(command),
  });
  assert.equal(result.status, 200);
  return result.json();
}
try {
  const store = new FileMatchStore(dir);
  engine = await createLocalServer({ store, meta });
  await assert.rejects(createLocalServer({dataDir: dir, meta}), /ENGINE_ALREADY_RUNNING_OR_RECOVERY_REQUIRED/);
  await mkdir(store.backupPath);
  // A directory at the temporary snapshot path makes snapshot writes fail.
  await mkdir(store.snapshotPath + '.tmp');
  const first = await send();
  assert.equal(first.state.homeScore, 1);
  assert.equal(first.duplicate, false);
  assert.ok(store.snapshotError);
  const base = 'http://127.0.0.1:' + engine.address.port;
  const headers = { authorization: 'Bearer ' + engine.token };
  assert.equal((await fetch(base + '/api/v1/diagnostics')).status, 401);
  const diag = await (await fetch(base + '/api/v1/diagnostics', { headers })).json();
  assert.equal(diag.snapshotWarning, 'SNAPSHOT_FAILED');
  assert.equal(diag.recoveryRequired, false);
  assert.equal((await send()).duplicate, true);
  // Inject the recovery latch to verify API behavior (not a real disk fault).
  store.journalError = 'INJECTED';
  assert.equal((await fetch(base + '/health')).status, 503);
  const blocked = await fetch(base + '/api/v1/commands', { method: 'POST', headers: { ...headers, 'content-type': 'application/json' }, body: JSON.stringify({...command, commandId: 'blocked', expectedRevision: 1}) });
  assert.equal(blocked.status, 503);
  assert.equal((await blocked.json()).error, 'JOURNAL_RESTART_REQUIRED');
  await engine.close(); engine = null;
  engine = await createLocalServer({ dataDir: dir, meta });
  const retry = await send();
  assert.equal(retry.duplicate, true);
  assert.equal(retry.state.homeScore, 1);
  await engine.close(); engine = null;
  // Real torn journal tail: startup retains the last complete state but
  // must immediately advertise recovery required and refuse new commands.
  const independent = new FileMatchStore(dir);
  const saved = await independent.load();
  await mkdir(independent.lockPath);
  await assert.rejects(independent.commit(saved), /WRITER_LOCK_BUSY/);
  await rm(independent.lockPath, { recursive: true });
  await assert.rejects(independent.commit(saved), /STALE_REVISION/);
  // A failed commit must release its own lock.
  await mkdir(independent.lockPath);
  await rm(independent.lockPath, { recursive: true });
  // Listener startup failure must release engine ownership.
  const otherDir = await mkdtemp(path.join(os.tmpdir(), 'sagi-owner-'));
  const other = await createLocalServer({dataDir: otherDir, meta});
  try {
    await assert.rejects(createLocalServer({dataDir: dir, meta, port: other.address.port}), /EADDRINUSE/);
  } finally {
    await other.close();
    await rm(otherDir, {recursive:true, force:true});
  }
  await appendFile(store.journalPath, '{"kind":"STATE_COMMIT"');
  engine = await createLocalServer({ dataDir: dir, meta });
  const recoveredBase = 'http://127.0.0.1:' + engine.address.port;
  const recoveredHeaders = { authorization: 'Bearer ' + engine.token };
  assert.equal((await fetch(recoveredBase + '/health')).status, 503);
  const recovered = await (await fetch(recoveredBase + '/api/v1/state', { headers: recoveredHeaders })).json();
  assert.equal(recovered.state.homeScore, 1);
  const refused = await fetch(recoveredBase + '/api/v1/commands', { method: 'POST', headers: { ...recoveredHeaders, 'content-type': 'application/json' }, body: JSON.stringify({...command, commandId: 'after_torn_tail', expectedRevision: 1}) });
  assert.equal(refused.status, 503);
  assert.equal((await refused.json()).error, 'JOURNAL_RESTART_REQUIRED');
  console.log('SNAPSHOT FAILURE RECOVERY PASS');
} finally {
  if (engine) await engine.close();
  await rm(dir, { recursive: true, force: true });
}
