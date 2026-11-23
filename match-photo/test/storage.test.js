const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('fs');
const os=require('os');
const path=require('path');
const {storageLayout,diskStats,assertCapacity}=require('../lib/storage');

test('creates event-scoped storage directories',()=>{
  const root=fs.mkdtempSync(path.join(os.tmpdir(),'sagi-photo-'));
  const x=storageLayout(root,'evt_123');
  assert.ok(fs.existsSync(x.originals));
  assert.ok(fs.existsSync(x.previews));
  assert.ok(x.originals.includes(path.join('events','evt_123','originals')));
});

test('sanitizes event id in paths',()=>{
  const root=fs.mkdtempSync(path.join(os.tmpdir(),'sagi-photo-'));
  const x=storageLayout(root,'../bad/event');
  assert.ok(x.eventDir.startsWith(root));
  assert.ok(!path.relative(root,x.eventDir).startsWith('..'));
});

test('reports disk statistics when platform supports statfs',()=>{
  const root=fs.mkdtempSync(path.join(os.tmpdir(),'sagi-photo-'));
  const stats=diskStats(root);
  assert.equal(typeof stats.supported,'boolean');
  if(stats.supported){
    assert.ok(stats.freeBytes>0);
    assert.ok(stats.totalBytes>0);
  }
});

test('capacity check accepts zero reserve on normal temp volume',()=>{
  const root=fs.mkdtempSync(path.join(os.tmpdir(),'sagi-photo-'));
  const stats=assertCapacity(root,1024,0);
  assert.equal(typeof stats.supported,'boolean');
});
