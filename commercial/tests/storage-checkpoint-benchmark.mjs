import assert from 'node:assert/strict';
import { mkdtemp, rm, stat, appendFile, readFile, writeFile } from 'node:fs/promises';
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
  const originalSnapshot = await readFile(store.snapshotPath, 'utf8');
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
  assert.ok((await stat(store.journalPath)).size - baselineBytes < 240 * 256, "compact checkpoint growth budget");
  const sorted = [...timings].sort((a,b)=>a-b);
  const percentile = p => sorted[Math.ceil(sorted.length*p)-1];
  console.log(JSON.stringify({checkpoints:timings.length,simulatedSeconds:3600,
    baselineBytes,journalBytes:(await stat(store.journalPath)).size,p50Ms:percentile(.5),
    p95Ms:percentile(.95),maxMs:sorted.at(-1)},null,2));
  assert.equal((await store.readJournal()).length,121);
  assert.ok((await stat(store.journalPath)).size > 65536, 'exercise multiple stream chunks');
  // Independent cooperative writers must invalidate another store's cached head.
  const peer = new FileMatchStore(root);
  const next = {...state, clock:{...state.clock, elapsedSeconds:3615}};
  await peer.checkpointClock(next);
  await assert.rejects(store.checkpointClock(state), /INVALID_CLOCK_CHECKPOINT/);
  state = {...next, clock:{...next.clock, elapsedSeconds:3630}};
  const returned = await store.checkpointClock(state);
  returned.clock.elapsedSeconds = 999999;
  state = {...state, clock:{running:true, elapsedSeconds:3645}};
  await store.checkpointClock(state);
  assert.deepEqual((await new FileMatchStore(root).load()).clock, state.clock);
  // Reject a syntactically valid checkpoint for the wrong fixture.
  assert.equal(await readFile(store.snapshotPath, 'utf8'), originalSnapshot,
    'clock checkpoints must not rewrite full snapshot');
  const validJournal = await readFile(store.journalPath, 'utf8');
  await appendFile(store.journalPath, JSON.stringify({kind:'CLOCK_CHECKPOINT',
    fixtureId:'wrong', revision:state.revision, elapsedSeconds:3615})+'\n');
  await assert.rejects(new FileMatchStore(root).load(), /INVALID_JOURNAL_CLOCK_CHECKPOINT/);
  await assert.rejects(store.checkpointClock(state), /INVALID_JOURNAL_CLOCK_CHECKPOINT/);
  assert.equal(store.journalError, 'JOURNAL_SCAN_REQUIRES_RECOVERY');
  await writeFile(store.journalPath, validJournal);
  await assert.rejects(store.checkpointClock(state), /JOURNAL_RESTART_REQUIRED/);
  const reopened = new FileMatchStore(root);
  assert.deepEqual((await reopened.load()).clock, state.clock);
  assert.equal(reopened.journalError, null);
  // Losing an established journal must not silently start a new history.
  await rm(reopened.journalPath);
  await assert.rejects(reopened.checkpointClock(state), /JOURNAL_DISAPPEARED/);
  assert.equal(reopened.journalError, 'JOURNAL_SCAN_REQUIRES_RECOVERY');
  await assert.rejects(stat(reopened.journalPath), {code:'ENOENT'});
  await writeFile(reopened.journalPath, validJournal);
  await assert.rejects(reopened.checkpointClock(state), /JOURNAL_RESTART_REQUIRED/);
  // A torn compact record is ignored on recovery but blocks mutation.
  await appendFile(store.journalPath, '{"kind":"CLOCK_CHECKPOINT"');
  const torn = new FileMatchStore(root);
  assert.deepEqual((await torn.load()).clock, state.clock);
  assert.equal(torn.journalError, 'TORN_JOURNAL_REQUIRES_REPAIR');
  await assert.rejects(torn.checkpointClock(state), /JOURNAL_RESTART_REQUIRED/);
  await writeFile(store.journalPath, validJournal);
  // A malformed complete record must not be hidden by later valid commits.
  await appendFile(store.journalPath, '{invalid json}\n', 'utf8');
  await assert.rejects(new FileMatchStore(root).load(), SyntaxError);
  console.log('Storage checkpoint benchmark PASS (correctness only)');
} finally {
  await rm(root,{recursive:true,force:true});
}
