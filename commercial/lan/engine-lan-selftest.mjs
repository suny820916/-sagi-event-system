import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { createLocalServer } from '../core/local-server.mjs';
import { createEngineLanGateway } from './engine-lan-bridge.mjs';

const dir = await mkdtemp(path.join(os.tmpdir(), 'sagi-lan-engine-'));
let engine, gateway, base, token;
let now = 0;
async function start() {
  engine = await createLocalServer({ dataDir: dir, clockNow: () => now, checkpointIntervalMs: 0, meta: { fixtureId: 'lan-test', home: '主队', away: '客队' } });
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
  const clockCommand = (commandId, expectedRevision, running) => request('command', { commandId, expectedRevision, fixtureId: 'lan-test', type: 'SET_CLOCK_RUNNING', running });
  assert.equal((await clockCommand('clock_invalid01', 2, true)).status, 400);
  assert.equal((await request('command', { commandId: 'period_0000001', expectedRevision: 2, type: 'SET_PERIOD', period: '1H' })).status, 200);
  assert.equal((await clockCommand('clock_start001', 3, true)).status, 200);
  now += 17000;
  assert.equal((await clockCommand('clock_pause001', 4, false)).status, 200);
  now += 9000;
  assert.equal((await clockCommand('clock_pause001', 4, false)).status, 200);
  assert.deepEqual((await (await request('state')).json()).state.clock, { running: false, elapsedSeconds: 17 });
  await stop();
  await start();
  assert.deepEqual((await (await request('state')).json()).state.clock, { running: false, elapsedSeconds: 17 });
  const penalty = (id, revision, type, extra = {}) => request('command', { commandId: id, expectedRevision: revision, fixtureId: 'lan-test', type, ...extra });
  const scored = { side: 'HOME', outcome: 'SCORED' };
  assert.equal((await penalty('pen_before001', 5, 'PENALTY_ATTEMPT', scored)).status, 400);
  assert.equal((await penalty('pen_finish000', 5, 'FINISH_PENALTIES')).status, 400);
  assert.equal((await penalty('pen_start0001', 5, 'START_PENALTIES')).status, 200);
  assert.equal((await penalty('pen_start0002', 6, 'START_PENALTIES')).status, 400);
  assert.equal((await penalty('pen_goal00001', 6, 'PENALTY_ATTEMPT', scored)).status, 200);
  assert.equal((await penalty('pen_miss00001', 7, 'PENALTY_ATTEMPT', { side: 'AWAY', outcome: 'MISSED' })).status, 200);
  const attempts = (await (await request('state')).json()).state.penalties.history;
  const undo = { attemptId: attempts[1].attemptId };
  assert.equal((await penalty('pen_wrong0001', 8, 'UNDO_PENALTY_ATTEMPT', { attemptId: attempts[0].attemptId })).status, 400);
  assert.equal((await penalty('pen_undo00001', 8, 'UNDO_PENALTY_ATTEMPT', undo)).status, 200);
  await stop();
  await start();
  const retryUndo = await penalty('pen_undo00001', 8, 'UNDO_PENALTY_ATTEMPT', undo);
  assert.equal(retryUndo.status, 200);
  assert.equal((await retryUndo.json()).result.duplicate, true);
  const restored = (await (await request('state')).json()).state;
  assert.equal(restored.revision, 9);
  assert.equal(restored.homeScore, 1);
  assert.equal(restored.penalties.history.length, 1);
  assert.equal(restored.penalties.home, 1);
  assert.equal(restored.penalties.away, 0);
  assert.equal((await penalty('pen_undo00002', 9, 'UNDO_PENALTY_ATTEMPT', { attemptId: attempts[0].attemptId })).status, 200);
  await stop();
  await start();
  const restoredScored = (await (await request('state')).json()).state;
  assert.equal(restoredScored.penalties.home, 0);
  assert.equal(restoredScored.penalties.history.length, 0);
  assert.equal(restoredScored.homeScore, 1);
  // Beyond five rounds: preserve every attempt, order and result across a real server restart.
  const extra = [];
  for (let i = 0; i < 14; i++) {
    const side = i % 2 === 0 ? 'HOME' : 'AWAY';
    const outcome = i % 3 === 0 ? 'MISSED' : 'SCORED';
    const id = 'extra_pen_' + String(i).padStart(4, '0');
    const response = await penalty(id, 10 + i, 'PENALTY_ATTEMPT', { side, outcome });
    assert.equal(response.status, 200, 'extra attempt ' + i);
    extra.push({ side, outcome });
  }
  const beforeRestart = (await (await request('state')).json()).state;
  assert.equal(beforeRestart.penalties.history.length, 14);
  assert.deepEqual(beforeRestart.penalties.history.map(({ side, outcome }) => ({ side, outcome })), extra);
  await stop();
  await start();
  const afterRestart = (await (await request('state')).json()).state;
  assert.equal(afterRestart.revision, 24);
  assert.deepEqual(afterRestart.penalties.history.map(({ side, outcome }) => ({ side, outcome })), extra);
  assert.equal(afterRestart.penalties.home, extra.filter(a => a.side === 'HOME' && a.outcome === 'SCORED').length);
  assert.equal(afterRestart.penalties.away, extra.filter(a => a.side === 'AWAY' && a.outcome === 'SCORED').length);
  assert.equal(afterRestart.homeScore, 1);
  const retryExtra = await penalty('extra_pen_0000', 10, 'PENALTY_ATTEMPT', extra[0]);
  assert.equal(retryExtra.status, 200);
  assert.equal((await retryExtra.json()).result.duplicate, true);
  assert.equal((await (await request('state')).json()).state.revision, 24);
  assert.equal((await penalty('pen_finish001', 24, 'FINISH_PENALTIES')).status, 200);
  await stop();
  await start();
  assert.equal((await penalty('pen_after0001', 25, 'PENALTY_ATTEMPT', scored)).status, 400);
  assert.equal((await penalty('pen_start0003', 25, 'START_PENALTIES')).status, 400);
  const retriedPenalty = await penalty('pen_goal00001', 6, 'PENALTY_ATTEMPT', scored);
  assert.equal(retriedPenalty.status, 200);
  assert.equal((await retriedPenalty.json()).result.duplicate, true);
  const finalState = (await (await request('state')).json()).state;
  assert.equal(finalState.revision, 25);
  assert.equal(finalState.period, 'FT');
  assert.equal(finalState.homeScore, 1);
  assert.equal(finalState.penalties.home, extra.filter(a => a.side === 'HOME' && a.outcome === 'SCORED').length);
  assert.equal(finalState.penalties.away, extra.filter(a => a.side === 'AWAY' && a.outcome === 'SCORED').length);
  assert.equal(finalState.penalties.history.length, 14);
  assert.equal(finalState.penalties.finished, true);
  // A late mobile retry after the final whistle must not resurrect a penalty,
  // change its original outcome, or append an event. Exercise all 14 IDs.
  const finalRevision = finalState.revision;
  const finalHistory = finalState.penalties.history.map(({ attemptId, side, outcome }) => ({ attemptId, side, outcome }));
  for (let i = 0; i < extra.length; i++) {
    const retry = await penalty('extra_pen_' + String(i).padStart(4, '0'), 10 + i, 'PENALTY_ATTEMPT', extra[i]);
    assert.equal(retry.status, 200, 'finalized retry ' + i);
    assert.equal((await retry.json()).result.duplicate, true, 'finalized duplicate ' + i);
  }
  // Concurrent retries can arrive together after a mobile reconnect or gateway replay.
  // They must all resolve to the original durable command without new events.
  const concurrentRetries = await Promise.all(extra.map((attempt, i) =>
    penalty('extra_pen_' + String(i).padStart(4, '0'), 10 + i, 'PENALTY_ATTEMPT', attempt)
  ));
  assert.ok(concurrentRetries.every(response => response.status === 200), 'concurrent finalized retry HTTP status');
  const concurrentBodies = await Promise.all(concurrentRetries.map(response => response.json()));
  assert.ok(concurrentBodies.every(body => body.result?.duplicate === true), 'concurrent finalized retry deduplication');
  const afterLateRetries = (await (await request('state')).json()).state;
  assert.equal(afterLateRetries.revision, finalRevision);
  assert.deepEqual(afterLateRetries.penalties.history.map(({ attemptId, side, outcome }) => ({ attemptId, side, outcome })), finalHistory);
  assert.equal(afterLateRetries.penalties.finished, true);
  await engine.close(); engine = null;
  assert.equal((await request('state')).status, 503);
  console.log('LAN ENGINE INTEGRATION PASS');
} finally {
  await stop();
  await rm(dir, { recursive: true, force: true });
}
