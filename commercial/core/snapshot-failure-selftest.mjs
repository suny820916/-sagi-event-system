import assert from 'node:assert/strict';
import { mkdtemp, mkdir, rm } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { FileMatchStore } from './file-store.mjs';
import { createLocalServer } from './local-server.mjs';

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
  console.log('SNAPSHOT FAILURE RECOVERY PASS');
} finally {
  if (engine) await engine.close();
  await rm(dir, { recursive: true, force: true });
}
