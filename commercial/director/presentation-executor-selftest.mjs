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
