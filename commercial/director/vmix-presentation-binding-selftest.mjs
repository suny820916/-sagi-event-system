import assert from 'node:assert/strict';
import {VMixAdapter} from '../core/vmix-adapter.mjs';
import {bindVMixPresentation} from './vmix-presentation-binding.mjs';
import {PresentationExecutor} from './presentation-executor.mjs';
const graphics=Object.fromEntries(['competition','matchup','home-lineup','away-lineup','goal-player','yellow-card','red-card','substitution'].map((n,i)=>[n,'G'+i]));
const keys=['CAM1',...Object.values(graphics)];
let active=1, missing=false, calls=[];
const adapter=new VMixAdapter({fetchImpl:async(url,options)=>{
  assert.equal(options.redirect,'error');
  options.signal.throwIfAborted();
  if(url.searchParams.has('Function')){
    assert.equal(url.searchParams.get('Function'),'Cut');
    const key=url.searchParams.get('Input');calls.push(key);active=keys.indexOf(key)+1;
    return new Response('OK');
  }
  return new Response('<vmix><inputs>'+keys.filter(k=>!missing||k!=='G7').map(k=>'<input key="'+k+'" number="'+(keys.indexOf(k)+1)+'">'+k+'</input>').join('')+'</inputs><active>'+active+'</active></vmix>');
}});
const output=bindVMixPresentation({adapter,graphics,programKeys:['CAM1']});
const executor=new PresentationExecutor({...output,wait:async()=>{}});
assert.equal((await executor.play({type:'INTRO',cueId:'intro-0001',programInput:'CAM1'})).status,'completed');
assert.deepEqual(calls,['G0','G1','G2','G3','CAM1']);
missing=true;
await assert.rejects(output.showGraphic('competition'),/VMIX_MAPPING_MISSING/);
assert.equal(calls.length,5);
const cancelled=new AbortController();cancelled.abort();
await assert.rejects(output.showGraphic('competition',{signal:cancelled.signal}));
assert.equal(calls.length,5);
missing=false;
const takeover=new PresentationExecutor({...output,wait:async()=>{active=1;}});
assert.equal((await takeover.play({type:'INTRO',cueId:'intro-0002',programInput:'CAM1'})).status,'uncertain');
assert.equal(takeover.status.blocked,true);
assert.deepEqual(calls,['G0','G1','G2','G3','CAM1','G0']);
const recovery=new PresentationExecutor({...output,wait:async()=>{active=1;}});
assert.equal((await recovery.play({type:'GOAL',cueId:'goal-00002',programInput:'CAM1'})).status,'uncertain');
assert.deepEqual(calls,['G0','G1','G2','G3','CAM1','G0','G4']);
console.log('vMix presentation binding self-test PASS');

// Configuration is captured at binding time, not read from mutable caller arrays.
active=1;
const mutableGraphics={...graphics}, mutablePrograms=['CAM1'];
const frozen=bindVMixPresentation({adapter,graphics:mutableGraphics,programKeys:mutablePrograms});
mutableGraphics.competition='MISSING'; mutablePrograms[0]='MISSING';
assert.equal(await frozen.showGraphic('competition',{expectedActive:'CAM1'}),true);
assert.equal(await frozen.returnProgram('CAM1',{expectedActive:'competition'}),true);
assert.throws(()=>bindVMixPresentation({adapter,graphics,programKeys:'CAM1'}),/INVALID_PROGRAM_KEYS/);
console.log('vMix mapping snapshot regression PASS');

 // Duplicate identity must fail before any output, not be silently deduplicated.
const ambiguousAdapter={
 health:async()=>({ok:true,body:'<vmix><inputs><input key="CAM1" number="1">A</input><input key="CAM1" number="2">B</input></inputs><active>1</active></vmix>'}),
 cue:async()=>{throw Error('UNEXPECTED_CUT');}
};
const ambiguous=bindVMixPresentation({adapter:ambiguousAdapter,graphics,programKeys:['CAM1']});
await assert.rejects(ambiguous.showGraphic('competition'),/AMBIGUOUS_INPUT_KEYS/);
console.log('Duplicate input identity regression PASS');
