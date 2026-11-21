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
  state = applyCommand(state,{commandId:'start-clock',type:'SET_CLOCK',running:true,elapsedSeconds:0}).state;
  await store.commit(state);
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
      assert.equal(applyCommand(recovered,goal).duplicate,true);
    }
  }
  const sorted = [...timings].sort((a,b)=>a-b);
  const percentile = p => sorted[Math.ceil(sorted.length*p)-1];
  console.log(JSON.stringify({checkpoints:timings.length,simulatedSeconds:3600,
    journalBytes:(await stat(store.journalPath)).size,p50Ms:percentile(.5),
    p95Ms:percentile(.95),maxMs:sorted.at(-1)},null,2));
  assert.equal((await store.readJournal()).length,1);
  console.log('Storage checkpoint benchmark PASS (correctness only)');
} finally {
  await rm(root,{recursive:true,force:true});
}
