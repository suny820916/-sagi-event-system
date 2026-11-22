import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { createLocalServer } from '../core/local-server.mjs';
import { createEngineLanGateway } from './engine-lan-bridge.mjs';

const dir = await mkdtemp(path.join(os.tmpdir(), 'sagi-lan-engine-'));
let engine, gateway, base, token;
async function start() {
  engine = await createLocalServer({ dataDir: dir, meta: { fixtureId: 'lan-test', home: '主队', away: '客队' } });
  gateway = createEngineLanGateway(engine);
  const { port } = await gateway.listen();
  base = 'http://127.0.0.1:' + port;
  const code = gateway.pairing.issue({ localOperatorApproved: true }).code;
  const response = await fetch(base + '/api/v1/lan/redeem', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ code }) });
  assert.equal(response.status, 200);
  token = (await response.json()).token;
}
async function stop() {
  if (gateway) { await new Promise((resolve, reject) => gateway.server.close(e => e ? reject(e) : resolve())); gateway = null; }
  if (engine) { await engine.close(); engine = null; }
}
const request = (route, command) => fetch(base + '/api/v1/lan/' + route, {
  method: command ? 'POST' : 'GET',
  headers: { authorization: 'Bearer ' + token, 'content-type': 'application/json' },
  body: command ? JSON.stringify(command) : undefined,
});
try {
  await start();
  const goal = { commandId: 'goal_00000001', expectedRevision: 0, type: 'GOAL', side: 'HOME' };
  const wrongFixture = await request('command', { ...goal, fixtureId: 'another-match' });
  assert.equal(wrongFixture.status, 409);
  assert.equal((await (await request('state')).json()).state.homeScore, 0);
  goal.fixtureId = 'lan-test';
  const results = await Promise.all([request('command', goal), request('command', goal)]);
  assert.deepEqual(results.map(r => r.status), [200, 200]);
  assert.deepEqual((await Promise.all(results.map(r => r.json()))).map(r => r.result.duplicate).sort(), [false, true]);
  const conflict = await request('command', { ...goal, commandId: 'goal_00000002' });
  assert.equal(conflict.status, 409);
  assert.equal((await conflict.json()).revision, 1);
  assert.equal((await request('command', { ...goal, commandId: 'goal_00000003', expectedRevision: 1, side: 'LEFT' })).status, 400);
  await stop();
  await start();
  assert.equal((await request('command', { ...goal, fixtureId: 'another-match' })).status, 409);
  const duplicate = await request('command', goal);
  assert.equal(duplicate.status, 200);
  assert.equal((await duplicate.json()).result.duplicate, true);
  const state = (await (await request('state')).json()).state;
  assert.equal(state.homeScore, 1);
  assert.equal(state.revision, 1);
  assert.equal((await request('command', { commandId: 'card_00000001', expectedRevision: 1, type: 'RED', side: 'AWAY' })).status, 200);
  assert.equal((await (await request('state')).json()).state.awayRedCards, 1);
  await engine.close(); engine = null;
  assert.equal((await request('state')).status, 503);
  console.log('LAN ENGINE INTEGRATION PASS');
} finally {
  await stop();
  await rm(dir, { recursive: true, force: true });
}
