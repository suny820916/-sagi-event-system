import assert from 'node:assert/strict';
import {createPresentationOutput} from './presentation-output.mjs';
import {PresentationExecutor} from './presentation-executor.mjs';
const graphics=Object.fromEntries(['competition','matchup','home-lineup','away-lineup','goal-player','yellow-card','red-card','substitution'].map((n,i)=>[n,'G'+i]));
const calls=[]; let active='CAM1',time=0,confirm=true;
const options={graphics,programKeys:['CAM1'],timeoutMs:30,pollMs:10,now:()=>time,sleep:async ms=>{time+=ms;},cut:async key=>{calls.push(key);if(confirm)active=key;return true;},readActiveKey:async()=>active};
const output=createPresentationOutput(options);
const executor=new PresentationExecutor({...output,wait:async()=>{}});
assert.equal((await executor.play({type:'INTRO',cueId:'intro-0001',programInput:'CAM1'})).status,'completed');
assert.deepEqual(calls,['G0','G1','G2','G3','CAM1']);
assert.throws(()=>output.returnProgram('G0'),/PROGRAM_NOT_ALLOWED/);
assert.throws(()=>output.showGraphic('unknown'),/UNKNOWN_GRAPHIC/);
assert.throws(()=>createPresentationOutput({...options,programKeys:['G0']}),/INVALID_INPUT_MAPPING/);
confirm=false;
assert.equal((await executor.play({type:'GOAL',cueId:'goal-00001',programInput:'CAM1'})).status,'uncertain');
assert.equal(executor.status.blocked,true);
assert.deepEqual(calls,['G0','G1','G2','G3','CAM1','G4']);
const controller=new AbortController();controller.abort();
await assert.rejects(output.showGraphic('competition',{signal:controller.signal}));
assert.equal(calls.length,6);
console.log('presentation output self-test PASS');

// The deadline also covers a slow preflight, not just the confirmation poll.
const keepAlive=setInterval(()=>{},100);
try {
  let cuts=0;
  const slow=createPresentationOutput({...options,now:()=>performance.now(),readActiveKey:({signal})=>new Promise((resolve,reject)=>{
    signal.addEventListener('abort',()=>reject(signal.reason),{once:true});
  }),cut:async()=>{cuts++;return true;}});
  await assert.rejects(slow.showGraphic('competition',{expectedActive:'CAM1'}),{name:'TimeoutError'});
  assert.equal(cuts,0);
  assert.throws(()=>createPresentationOutput({...options,timeoutMs:30001}),/INVALID_TIMEOUT/);
} finally {clearInterval(keepAlive);}
console.log('presentation shared deadline regression PASS');
