// Run: node training/tests/sw-runtime.test.cjs
// Exercise service worker behavior in a mocked CacheStorage environment.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const code = fs.readFileSync(path.join(__dirname, '..', 'sw.js'), 'utf8');
const listeners = {};
const stores = new Map();
const origin = 'https://training.example.test/';
const makeResponse = (body, status = 200) => ({body, status});
const caches = {
  async open(name) {
    if (!stores.has(name)) stores.set(name, new Map());
    const entries = stores.get(name);
    return {
      async addAll(requests) { for (const req of requests) entries.set(req.url, makeResponse('cached:' + req.url)); },
      async match(req) { return entries.get(req.url); }
    };
  },
  async keys() { return [...stores.keys()]; },
  async delete(name) { return stores.delete(name); }
};
let fetches = 0;
const context = {
  self: {registration: {scope: origin}, clients: {claim: async () => {}}, addEventListener: (name, cb) => {listeners[name] = cb;}},
  caches, URL, Request: class { constructor(url) {this.url = url;} },
  Response: class { constructor(body, opts) {this.body=body; this.status=opts.status;} },
  fetch: async () => {fetches++; return makeResponse('network');}
};
vm.runInNewContext(code, context, {filename: 'sw.js'});
const runEvent = async (name, props={}) => {
  let pending;
  listeners[name]({...props, waitUntil: p => {pending=p;}, respondWith: p => {pending=p;}});
  return pending && await pending;
};
(async () => {
  assert.ok(listeners.install && listeners.activate && listeners.fetch);
  await runEvent('install');
  assert.equal(stores.size, 1);
  const cacheName = [...stores.keys()][0];
  for (const f of ['', 'index.html', 'iq.html', 'manifest.webmanifest', 'icon.svg'])
    assert.ok(stores.get(cacheName).has(origin+f), 'not precached: '+f);
  stores.set('sagi-training-obsolete', new Map());
  stores.set('unrelated-cache', new Map());
  await runEvent('activate');
  assert.ok(!stores.has('sagi-training-obsolete'));
  assert.ok(stores.has('unrelated-cache'));
  const cached = await runEvent('fetch', {request: {method:'GET',url:origin+'iq.html'}});
  assert.match(cached.body, /^cached:/);
  assert.equal(fetches, 0, 'offline shell should be cache-first');
  await runEvent('fetch', {request: {method:'POST',url:origin+'iq.html'}});
  await runEvent('fetch', {request: {method:'GET',url:origin+'not-cached.json'}});
  assert.equal(fetches, 0, 'unhandled requests must pass through');
  console.log('PASS: SW precache, cache rotation, cached fetch and request exclusions');
})().catch(e=>{console.error(e);process.exitCode=1;});
