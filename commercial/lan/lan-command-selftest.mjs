import assert from 'node:assert/strict';
import http from 'node:http';
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
assert.equal(g.server.requestTimeout, 15_000);
assert.equal(g.server.headersTimeout, 10_000);
assert.equal(g.server.timeout, 20_000);
assert.equal(g.server.keepAliveTimeout, 5_000);
assert.equal(g.server.maxRequestsPerSocket, 100);
const { port } = await g.listen();
const base = `http://127.0.0.1:${port}`;
// Use raw HTTP for Host overrides: fetch may silently replace the header.
const hostProbe = host => new Promise((resolve, reject) => {
  const req = http.get({ hostname: '127.0.0.1', port, path: '/api/v1/lan/health', headers: { Host: host } }, res => {
    const chunks = [];
    res.on('data', chunk => chunks.push(chunk));
    res.on('error', reject);
    res.on('end', () => resolve({ status: res.statusCode, json: async () => JSON.parse(Buffer.concat(chunks).toString('utf8')) }));
  });
  req.on('error', reject);
  req.setTimeout(5000, () => req.destroy(new Error('HOST_PROBE_TIMEOUT')));
});
const post = (body, token) => fetch(base + '/api/v1/lan/command', {
  method: 'POST',
  headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
  body: JSON.stringify(body),
});
try {
  const page = await fetch(base + '/mobile');
  assert.equal(page.status, 200);
  assert.match(page.headers.get('content-security-policy'), /script-src 'self'/);
  assert.match(await page.text(), /主队进球/);
  const script = await fetch(base + '/mobile.js');
  assert.equal(script.status, 200);
  const source = await script.text();
  assert.doesNotThrow(() => new Function(source));
  assert.match(source, /expectedRevision:state.revision/);
  // Execute the served browser script with simulated DOM/storage and transport.
  const saved = new Map();
  let sent = [], fail = true, score = 0, offline = false, expired = false, reads = 0;
  let poll, pageShow;
  function boot() {
    const elements = new Map();
    const document = { getElementById(id) {
      if (!elements.has(id)) elements.set(id, { value: '', disabled: false });
      return elements.get(id);
    }};
    const storage = { getItem: k => saved.get(k) ?? null, setItem: (k,v) => saved.set(k,v), removeItem: k => saved.delete(k) };
    const transport = async (url, opts) => {
      let data;
      if (url.endsWith('/redeem')) data = { token: 'test-token' };
      else if (url.endsWith('/state')) {
        reads++;
        if (offline) throw new Error('offline');
        if (expired) return {ok:false,status:401,json:async()=>({error:'expired'})};
        data = { state: { fixtureId: 'test-match', revision: score, homeScore: score, awayScore: 0 } };
      }
      else {
        const command = JSON.parse(opts.body);
        if (!sent.some(c => c.commandId === command.commandId)) score++;
        sent.push(command);
        if (fail) throw new Error('lost response');
        data = { result: {} };
      }
      return { ok: true, json: async () => data };
    };
    new Function('document','sessionStorage','fetch','window','crypto', source)(document,storage,transport,{addEventListener(name,fn){if(name === 'pageshow') pageShow=fn;},setInterval(fn){poll=fn;}},globalThis.crypto);
    return id => document.getElementById(id);
  }
  let phone = boot();
  await phone('pair').onclick();
  phone('home').onclick();
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(score, 1);
  assert.equal(saved.size, 1);
  phone = boot();
  assert.equal(phone('home').disabled, true);
  await phone('pair').onclick();
  assert.equal(phone('retry').disabled, false);
  fail = false;
  pageShow();
  assert.equal(phone('retry').disabled, true);
  await phone('retry').onclick();
  assert.equal(sent.length, 1, 'stale retry must not dispatch');
  await phone('refresh').onclick();
  assert.equal(phone('retry').disabled, false);
  await phone('retry').onclick();
  assert.equal(sent.length, 2);
  assert.deepEqual(sent[0], sent[1]);
  assert.equal(score, 1);
  assert.equal(saved.size, 0);
  assert.equal(phone('score').textContent, '1 : 0');
  const tick = async () => { poll(); await new Promise(resolve => setImmediate(resolve)); };
  score = 2; await tick();
  assert.equal(phone('score').textContent, '2 : 0');
  offline = true; await tick();
  assert.equal(phone('home').disabled, true);
  assert.equal(phone('score').textContent, '— : —');
  offline = false; await tick();
  assert.equal(phone('home').disabled, false);
  score = -1; await tick();
  assert.equal(phone('home').disabled, true);
  assert.equal(phone('score').textContent, '— : —');
  score = 2; await tick();
  assert.equal(phone('home').disabled, false);
  expired = true; await tick();
  assert.equal(phone('home').disabled, true);
  const before = reads; await tick(); assert.equal(reads,before);
  assert.equal(sent.length,2, 'polling must not replay mutations');
  assert.equal((await fetch(base + '/mobile', { headers: { origin: 'http://evil.example' } })).status, 403);
  const code = g.pairing.issue({ localOperatorApproved: true }).code;
  const redeem = await fetch(base + '/api/v1/lan/redeem', {
    method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ code }),
  });
  assert.equal(redeem.status, 200);
  const { token } = await redeem.json();
  const rebinding = await hostProbe('attacker.example:' + port);
  assert.equal(rebinding.status, 403);
  assert.equal((await rebinding.json()).error, 'HOST_FORBIDDEN');
  for (const malformedHost of ['user@127.0.0.1:' + port, '127.0.0.1', '127.0.0.1:' + port + '/bad', '127.1:' + port, '2130706433:' + port, '127.0.0.1:0' + port]) {
    const response = await hostProbe(malformedHost);
    assert.equal(response.status, 400, 'malformed Host must be rejected: ' + malformedHost);
  }
  for (const target of [
    '/api/v1/lan/health?debug=1',
    '/api/v1/lan/%68ealth',
    '/api/v1/lan%2fhealth',
    '//attacker.example/api/v1/lan/health',
  ]) {
    const response = await fetch(base + target);
    assert.equal(response.status, 400, 'non-canonical target rejected: ' + target);
  }
  const sameOrigin = await fetch(base + '/api/v1/lan/health', { headers: { origin: base } });
  assert.equal(sameOrigin.status, 200, 'same-origin browser request must work');
  for (const origin of ['http://evil.example', base + '.evil.example', 'null', base + '/other', base + '/', base + '/a/..', 'https://127.0.0.1:' + port]) {
    const response = await fetch(base + '/api/v1/lan/health', { headers: { origin } });
    assert.equal(response.status, 403, 'foreign/malformed Origin must be rejected: ' + origin);
  }
  const wrongPort = await hostProbe('127.0.0.1:' + (port === 65535 ? port - 1 : port + 1));
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
  // Deterministically simulate revocation between initial authentication and
  // command admission without relying on socket timing.
  const nextCode = g.pairing.issue({ localOperatorApproved: true }).code;
  const nextToken = g.pairing.redeem(nextCode).token;
  const originalVerify = g.pairing.verify.bind(g.pairing);
  let checks = 0;
  g.pairing.verify = candidate => {
    const valid = originalVerify(candidate);
    if (++checks === 1) g.pairing.revoke(candidate);
    return valid;
  };
  try {
    assert.equal((await post({ ...goal, commandId: 'goal_00000004', expectedRevision: 1 }, nextToken)).status, 401);
    assert.equal(accepted.length, 1, 'revoked session must not dispatch a command');
  } finally {
    g.pairing.verify = originalVerify;
  }
  console.log('lan-command-selftest PASS');
} finally {
  await new Promise(resolve => g.server.close(resolve));
}
