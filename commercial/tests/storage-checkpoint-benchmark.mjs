import assert from 'node:assert/strict';
import { mkdtemp, rm, stat } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { performance } from 'node:perf_hooks';
import { FileMatchStore } from '../core/file-store.mjs';
import { createInitialMatchState, applyCommand } from '../core/match-core.mjs';

const root = await mkdtemp(path.join(os.tmpdir(),'sagi-storage-bench-'));
try {
  const store = new FileMatchStore(root);
  let state = createInitialMatchState({fixtureId:'bench',home:'主队',away:'客队'});
  const goal = {commandId:'first-goal',type:'GOAL',side:'HOME'};
  state = applyCommand(state,goal).state;
  await store.commit(state,state.eventLog.at(-1));
  // Build realistic retained history before the checkpoint loop.
  for (let i=0;i<120;i++) {
    const command = {commandId:'history-'+i,type:i%3===0?'SUB':'YELLOW',
      side:i%2===0?'HOME':'AWAY',player:{id:'p'+i,name:'球员'+i,number:String(i%99+1)}};
    const result = applyCommand(state,command);
    state = result.state;
    await store.commit(state,result.event);
  }
  state = applyCommand(state,{commandId:'first-half',type:'SET_PERIOD',period:'1H'}).state;
  await store.commit(state);
  state = applyCommand(state,{commandId:'start-clock',type:'SET_CLOCK',running:true,elapsedSeconds:0}).state;
  await store.commit(state);
  const baselineBytes = (await stat(store.journalPath)).size;
  const timings = [];
  for(let i=1;i<=240;i++){
    state = {...state,clock:{...state.clock,elapsedSeconds:i*15}};
    const start = performance.now();
    await store.checkpointClock(state);
    timings.push(performance.now()-start);
    if(i%60===0){
      const recovered = await new FileMatchStore(root).load();
      assert.equal(recovered.revision,state.revision);
      assert.deepEqual(recovered.clock,state.clock);
      assert.equal(recovered.homeScore,1);
      assert.equal(recovered.eventLog.length,121);
      assert.equal(recovered.processedCommandIds.length,123);
      assert.equal(applyCommand(recovered,goal).duplicate,true);
    }
  }
  const sorted = [...timings].sort((a,b)=>a-b);
  const percentile = p => sorted[Math.ceil(sorted.length*p)-1];
  console.log(JSON.stringify({checkpoints:timings.length,simulatedSeconds:3600,
    baselineBytes,journalBytes:(await stat(store.journalPath)).size,p50Ms:percentile(.5),
    p95Ms:percentile(.95),maxMs:sorted.at(-1)},null,2));
  assert.equal((await store.readJournal()).length,121);
  console.log('Storage checkpoint benchmark PASS (correctness only)');
} finally {
  await rm(root,{recursive:true,force:true});
}
