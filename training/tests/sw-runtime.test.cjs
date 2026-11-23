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
const makeResponse = (body, status = 200) => ({body, status, ok: status >= 200 && status < 300, clone() {return makeResponse(body, status);}});
const caches = {
  async open(name) {
    if (cacheOpenFails) throw Error('cache unavailable');
    if (!stores.has(name)) stores.set(name, new Map());
    const entries = stores.get(name);
    return {
      async addAll(requests) { for (const req of requests) entries.set(req.url, makeResponse('cached:' + req.url)); },
      async match(req) { return entries.get(req.url); },
      async put(req, response) { if (cacheWriteFails) throw Error('quota exceeded'); entries.set(req.url, response); }
    };
  },
  async keys() { return [...stores.keys()]; },
  async delete(name) { return stores.delete(name); }
};
let fetches = 0;
let networkDown = false;
let cacheWriteFails = false;
let cacheOpenFails = false;
const context = {
  self: {registration: {scope: origin}, clients: {claim: async () => {}}, addEventListener: (name, cb) => {listeners[name] = cb;}},
  caches, URL, Request: class { constructor(url) {this.url = url;} },
  Response: class { constructor(body, opts) {this.body=body; this.status=opts.status;} },
  fetch: async () => {fetches++; if(networkDown)throw Error('offline'); return makeResponse('network');}
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
  // A missing precached entry must be restored from the network for later offline use.
  stores.get(cacheName).delete(origin+'iq.html');
  const recovered = await runEvent('fetch', {request: {method:'GET',url:origin+'iq.html'}});
  assert.equal(recovered.body, 'network');
  assert.equal(fetches, 1);
  assert.equal(stores.get(cacheName).get(origin+'iq.html').body, 'network');
  await runEvent('fetch', {request: {method:'GET',url:origin+'iq.html'}});
  assert.equal(fetches, 1, 'restored asset should be served from cache');
  // CacheStorage quota errors must not discard a successful network response.
  stores.get(cacheName).delete(origin+'iq.html');
  cacheWriteFails = true;
  const quotaFallback = await runEvent('fetch', {request: {method:'GET',url:origin+'iq.html'}});
  assert.equal(quotaFallback.body, 'network');
  assert.ok(!stores.get(cacheName).has(origin+'iq.html'), 'quota failure must not pretend cache succeeded');
  cacheWriteFails = false;
  // A genuinely offline cache miss must produce an explicit 503 rather than an uncaught rejection.
  networkDown = true;
  const offline = await runEvent('fetch', {request: {method:'GET',url:origin+'iq.html'}});
  assert.equal(offline.status, 503);
  assert.match(offline.body, /离线缓存/);
  networkDown = false;
  // CacheStorage may reject in restricted/private contexts: network must still work.
  cacheOpenFails = true;
  const cacheUnavailable = await runEvent('fetch', {request: {method:'GET',url:origin+'iq.html'}});
  assert.equal(cacheUnavailable.body, 'network');
  networkDown = true;
  const unavailableOffline = await runEvent('fetch', {request: {method:'GET',url:origin+'iq.html'}});
  assert.equal(unavailableOffline.status, 503);
  cacheOpenFails = false;
  networkDown = false;
  console.log('PASS: SW precache, rotation, recovery, quota fallback, cache unavailable, offline 503 and exclusions');
})().catch(e=>{console.error(e);process.exitCode=1;});
