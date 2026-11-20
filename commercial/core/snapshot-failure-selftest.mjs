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
  assert.equal((await send()).duplicate, true);
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
