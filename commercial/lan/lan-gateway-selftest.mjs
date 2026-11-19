import assert from 'node:assert/strict';
import { createLanGateway } from './lan-gateway.mjs';

const g = createLanGateway({ getState: () => ({ homeScore: 2 }) });
assert.throws(() => createLanGateway({ host: '0.0.0.0' }), /EXPLICIT_INTERFACE_REQUIRED/);
const { port } = await g.listen();
const base = `http://127.0.0.1:${port}`;
try {
  let r = await fetch(base + '/api/v1/lan/health');
  assert.equal(r.status, 200);
  r = await fetch(base + '/api/v1/lan/issue', { method: 'POST' });
  assert.equal(r.status, 403);
  r = await fetch(base + '/api/v1/lan/state');
  assert.equal(r.status, 401);
  const code = g.pairing.issue({ localOperatorApproved: true }).code;
  r = await fetch(base + '/api/v1/lan/redeem', {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ code }),
  });
  assert.equal(r.status, 200);
  const { token } = await r.json();
  r = await fetch(base + '/api/v1/lan/state', {
    headers: { authorization: `Bearer ${token}` },
  });
  assert.equal(r.status, 200);
  assert.deepEqual((await r.json()).state, { homeScore: 2 });
  r = await fetch(base + '/api/v1/lan/redeem', {
    method: 'POST', headers: { origin: 'https://evil.test', 'content-type': 'application/json' },
    body: '{}',
  });
  assert.equal(r.status, 403);
  for (let i = 0; i < 8; i++) {
    r = await fetch(base + '/api/v1/lan/redeem', {
      method: 'POST', headers: { 'content-type': 'application/json' }, body: '{}',
    });
  }
  assert.equal(r.status, 429);
  g.pairing.revoke(token);
  r = await fetch(base + '/api/v1/lan/state', {
    headers: { authorization: `Bearer ${token}` },
  });
  assert.equal(r.status, 401);
  console.log('lan-gateway-selftest PASS');
} finally {
  await new Promise(resolve => g.server.close(resolve));
}
