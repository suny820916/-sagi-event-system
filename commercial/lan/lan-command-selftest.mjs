import assert from 'node:assert/strict';
import { createLanGateway } from './lan-gateway.mjs';

const accepted = [];
let revision = 0;
const seen = new Map();
const g = createLanGateway({
  getState: () => ({ revision }),
  submitCommand: async command => {
    if (seen.has(command.commandId)) return seen.get(command.commandId);
    if (command.expectedRevision !== revision) {
      const err = new Error('stale revision');
      err.code = 'REVISION_CONFLICT';
      throw err;
    }
    revision++;
    accepted.push(command);
    const result = { revision };
    seen.set(command.commandId, result);
    return result;
  },
});
const { port } = await g.listen();
const base = `http://127.0.0.1:${port}`;
const post = (body, token) => fetch(base + '/api/v1/lan/command', {
  method: 'POST',
  headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
  body: JSON.stringify(body),
});
try {
  const code = g.pairing.issue({ localOperatorApproved: true }).code;
  const redeem = await fetch(base + '/api/v1/lan/redeem', {
    method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ code }),
  });
  assert.equal(redeem.status, 200);
  const { token } = await redeem.json();
  const rebinding = await fetch(base + '/api/v1/lan/health', { headers: { host: 'attacker.example' } });
  assert.equal(rebinding.status, 403);
  assert.equal((await rebinding.json()).error, 'HOST_FORBIDDEN');
  for (const malformedHost of ['user@127.0.0.1:' + port, '127.0.0.1', '127.0.0.1:' + port + '/bad']) {
    const response = await fetch(base + '/api/v1/lan/health', { headers: { host: malformedHost } });
    assert.equal(response.status, 400, 'malformed Host must be rejected: ' + malformedHost);
  }
  const sameOrigin = await fetch(base + '/api/v1/lan/health', { headers: { origin: base } });
  assert.equal(sameOrigin.status, 200, 'same-origin browser request must work');
  for (const origin of ['http://evil.example', base + '.evil.example', 'null', base + '/other', 'https://127.0.0.1:' + port]) {
    const response = await fetch(base + '/api/v1/lan/health', { headers: { origin } });
    assert.equal(response.status, 403, 'foreign/malformed Origin must be rejected: ' + origin);
  }
  const wrongPort = await fetch(base + '/api/v1/lan/health', { headers: { host: '127.0.0.1:' + (port + 1) } });
  assert.equal(wrongPort.status, 400, 'wrong Host port must be rejected');
  const goal = { commandId: 'goal_00000001', expectedRevision: 0, type: 'GOAL', team: 'home' };
  assert.equal((await post(goal)).status, 401);
  assert.equal((await post({ type: 'GOAL' }, token)).status, 400);
  assert.equal((await post({ ...goal, type: 'VMIX_RECORD_START' }, token)).status, 403);
  assert.equal((await post({ ...goal, type: 'ADMIN_RESET' }, token)).status, 403);
  assert.equal((await fetch(base + '/api/v1/lan/command', { method: 'POST', headers: { authorization: `Bearer ${token}` }, body: JSON.stringify(goal) })).status, 415);
  assert.equal((await post(goal, token)).status, 200);
  assert.equal((await post(goal, token)).status, 200);
  assert.equal(accepted.length, 1);
  assert.equal((await post({ ...goal, commandId: 'goal_00000002' }, token)).status, 409);
  const state = await fetch(base + '/api/v1/lan/state', { headers: { authorization: `Bearer ${token}` } });
  assert.equal((await state.json()).state.revision, 1);
  g.pairing.revoke(token);
  assert.equal((await post({ ...goal, commandId: 'goal_00000003', expectedRevision: 1 }, token)).status, 401);
  console.log('lan-command-selftest PASS');
} finally {
  await new Promise(resolve => g.server.close(resolve));
}
