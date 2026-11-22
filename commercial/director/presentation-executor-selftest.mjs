import assert from 'node:assert/strict';
import { PresentationExecutor } from './presentation-executor.mjs';
const calls = [];
const req = (cueId,type='INTRO') => ({cueId,type,programInput:'CAM1'});
const e = new PresentationExecutor({
 showGraphic: async g => {calls.push(g);return true;},
 returnProgram: async i => {calls.push(i);return true;},
 wait: async ms => calls.push(ms)
});
assert.equal((await e.play(req('intro-001'))).status,'completed');
assert.deepEqual(calls,['competition',4000,'matchup',4000,'home-lineup',8000,'away-lineup',8000,'CAM1']);
assert.equal((await e.play(req('intro-001'))).status,'duplicate');
let release;
const c = new PresentationExecutor({
 showGraphic: async () => true,
 returnProgram: async () => {throw Error('must not return after manual takeover');},
 wait: () => new Promise(r => {release=r;})
});
const pending=c.play(req('goal-0001','GOAL'));
await Promise.resolve();
await assert.rejects(c.play(req('goal-0002','GOAL')), /DIRECTOR_BUSY/);
assert.equal(c.cancel(),true); release();
assert.equal((await pending).status,'cancelled');
await assert.rejects(c.play(req('goal-0002','GOAL')), /MANUAL_RECOVERY_REQUIRED/);
c.acknowledgeManualRecovery();
assert.equal(c.status.blocked,false);
const u = new PresentationExecutor({showGraphic:async()=>false,returnProgram:async()=>true});
assert.equal((await u.play(req('card-0001','RED'))).status,'uncertain');
assert.equal(u.status.blocked,true);
console.log('presentation executor self-test PASS');

import { FileCueClaims } from './file-cue-claims.mjs';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
const dir = await mkdtemp(join(tmpdir(),'sagi-cues-'));
try {
  let outputs=0;
  const make=()=>new PresentationExecutor({
    cueClaims:new FileCueClaims(dir),
    showGraphic:async()=>{outputs++;return true;},
    returnProgram:async()=>true,wait:async()=>{}
  });
  const results=await Promise.all([make().play(req('durable-001','GOAL')),make().play(req('durable-001','GOAL'))]);
  assert.deepEqual(results.map(r=>r.status).sort(),['completed','duplicate']);
  assert.equal((await make().play(req('durable-001','GOAL'))).status,'duplicate');
  assert.equal(outputs,1);
  const bad=new PresentationExecutor({cueClaims:{claim:async()=>{throw Error('disk');}},showGraphic:async()=>{outputs++;return true;},returnProgram:async()=>true});
  assert.equal((await bad.play(req('durable-002','GOAL'))).status,'uncertain');
  assert.equal(bad.status.blocked,true);
  assert.equal(outputs,1);
} finally { await rm(dir,{recursive:true,force:true}); }
console.log('persistent cue claim self-test PASS');

import { DirectorOwnership } from './director-ownership.mjs';
const lockDir = await mkdtemp(join(tmpdir(),'sagi-owner-'));
try {
  const path = join(lockDir,'output.lock');
  let entered, resume;
  const started = new Promise(r=>{entered=r;});
  const hold = new Promise(r=>{resume=r;});
  const make = (wait=async()=>{}, showGraphic=async()=>true) => new PresentationExecutor({
    ownership:new DirectorOwnership(path), showGraphic, returnProgram:async()=>true, wait
  });
  const first = make(async()=>{entered();await hold;});
  const running = first.play(req('owner-001','GOAL'));
  await started;
  const second = make();
  assert.equal((await second.play(req('owner-002','GOAL'))).status,'busy');
  resume();
  assert.equal((await running).status,'completed');
  assert.equal((await second.play(req('owner-002','GOAL'))).status,'completed');
  assert.equal((await make(undefined,async()=>false).play(req('owner-003','GOAL'))).status,'uncertain');
  assert.equal((await make().play(req('owner-004','GOAL'))).status,'busy');
} finally { await rm(lockDir,{recursive:true,force:true}); }
console.log('director ownership self-test PASS');
