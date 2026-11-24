import fs from 'node:fs';

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
