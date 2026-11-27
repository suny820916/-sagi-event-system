import fs from 'node:fs';
import assert from 'node:assert/strict';

const control=fs.readFileSync('intro/v45-lan.html','utf8');
const output=fs.readFileSync('intro/vmix-v45-lan.html','utf8');
const fixture=JSON.parse(fs.readFileSync('intro/tests/fixtures/v434-goal-pipeline-scenarios.json','utf8'));

function check(name,ok){console.log((ok?'PASS':'FAIL')+' '+name);return !!ok}
const baseline=[
 ['fixture version',fixture.version==='V4.34-GOAL-PIPELINE-PREP-1'],
 ['scenario count',Array.isArray(fixture.scenarios)&&fixture.scenarios.length>=9],
 ['event identity generator exists',control.includes('function mdNextEventIdentity(')],
 ['event log exists',control.includes('eventLog:')],
 ['replay markers exist',control.includes('replayMarkers:')],
 ['instant replay entrypoint exists',control.includes('instantReplayGenerate')],
 ['undo path exists',control.includes('function mdUndo')||control.includes('function mdUndoLast')||control.includes('mdUndo')],
 ['Signature Core reaches control',control.includes('SAGISignatureCore')],
 ['Signature Core reaches output',output.includes('SAGISignatureCore')],
 ['local Bridge matchday transport exists',control.includes("lanPost('/api/matchday'")]
];
const baselineOk=baseline.map(([n,ok])=>check(n,ok)).every(Boolean);

const future=[
 ['goal replay marker eventId linkage',/replayMarkers[\s\S]{0,800}eventId/.test(control)],
 ['highlight candidate linkage',/highlight\s*[:=]\s*true/.test(control)],
 ['derived player goal stats',/(playerStats|goalStats|derive.*stat|stats.*eventLog)/i.test(control)],
 ['ReplayStopEvents present',control.includes('ReplayStopEvents')],
 ['configured main return present',/MAIN_WIDE|returnSlot|configured main/i.test(control)],
 ['goal undo touches replay marker',/(UNDO|Undo|undo)[\s\S]{0,1200}replayMarkers/.test(control)]
];
const missing=future.filter(([,ok])=>!ok).map(([n])=>n);
console.log('V4.34_PREP_GAPS '+JSON.stringify(missing));
console.log('V4.34_PREP_BASELINE '+JSON.stringify({baselineOk,missingFuture:missing.length,scenarioCount:fixture.scenarios.length}));
if(!baselineOk)process.exit(1);

 // Contract model for preparation only. No controller code, network or vMix.
const key = ({fixture, id}) => JSON.stringify([fixture, id]);
function apply(events, operation) {
  const identity = key(operation);
  if (operation.kind === 'UNDO') return events.filter(event => key(event) !== identity);
  if (operation.displayOnly || events.some(event => key(event) === identity)) return events;
  return [...events, operation];
}
function derive(events, fixture) {
  const current = events.filter(event => event.fixture === fixture);
  const scores = [0, 0];
  const players = new Map();
  const markers = current.map(event => {
    scores[event.side === 'AWAY' ? 1 : 0]++;
    const player = JSON.stringify([event.side, event.player]);
    if (event.player) players.set(player, (players.get(player) ?? 0) + 1);
    return {eventId:event.id, fixture:event.fixture, highlight:true};
  });
  return {scores, players:[...players], markers};
}
async function present(effect) {
  try {
    await effect('mark');
    await effect('playLatest');
  } finally {
    try { await effect('stop'); }
    finally { await effect('returnMain'); }
  }
}
const home = {kind:'GOAL', fixture:'match-a', id:'1', side:'HOME', player:'7'};
const away = {...home, id:'2', side:'AWAY'};
const other = {...home, fixture:'match-b'};
let events = [home, home, away, other, {...home,id:'display',displayOnly:true}].reduce(apply,[]);
assert.equal(events.length,3);
assert.deepEqual(derive(events,'match-a'),{
  scores:[1,1], players:[['["HOME","7"]',1],['["AWAY","7"]',1]],
  markers:[{eventId:'1',fixture:'match-a',highlight:true},{eventId:'2',fixture:'match-a',highlight:true}]
});
const restored = JSON.parse(JSON.stringify(events));
assert.deepEqual(derive(apply(restored,home),'match-a'),derive(events,'match-a'));
events = apply(restored,{...home,kind:'UNDO'});
assert.deepEqual(derive(events,'match-a').scores,[0,1]);
assert.deepEqual(derive(events,'match-a').players,[['["AWAY","7"]',1]]);
assert.deepEqual(derive(events,'match-a').markers.map(marker=>marker.eventId),['2']);
assert.deepEqual(derive(events,'match-b').scores,[1,0]);
for (const failure of [null,'mark','playLatest','stop']) {
  const trace = [];
  const durableBefore = JSON.stringify(events);
  const run = present(async step=>{
    trace.push(step);
    if (step === failure) throw new Error(step);
  });
  if (failure) await assert.rejects(run,{message:failure});
  else await run;
  assert.deepEqual(trace,failure==='mark'?['mark','stop','returnMain']:['mark','playLatest','stop','returnMain']);
  assert.equal(JSON.stringify(events),durableBefore);
}
console.log('V4.34_PREP_CONTRACT PASS: fixture identity, retries, exact undo, restore and replay cleanup');
