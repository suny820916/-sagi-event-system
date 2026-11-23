import assert from 'node:assert/strict';
import { createLanGateway } from './lan-gateway.mjs';

// Revoke a paired phone while the authoritative state read is awaiting I/O.
// The pending response must not leak the state after revocation.
let release;
let entered;
const started = new Promise(resolve => { entered = resolve; });
const pending = new Promise(resolve => { release = resolve; });
const gateway = createLanGateway({
  getState: async () => { entered(); await pending; return { fixtureId: 'private-fixture', homeScore: 4 }; },
});
const { port } = await gateway.listen();
try {
  const code = gateway.pairing.issue({ localOperatorApproved: true }).code;
  const token = gateway.pairing.redeem(code).token;
  const request = fetch(`http://127.0.0.1:${port}/api/v1/lan/state`, {
    headers: { authorization: `Bearer ${token}` },
  });
  await started;
  gateway.pairing.revoke(token);
  release();
  const response = await request;
  assert.equal(response.status, 401);
  assert.deepEqual(await response.json(), { error: 'UNAUTHORIZED' });
  console.log('LAN STATE REVOCATION PASS');
} finally {
  release?.();
  await new Promise(resolve => gateway.server.close(resolve));
}
