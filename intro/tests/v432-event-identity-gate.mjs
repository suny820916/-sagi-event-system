// SAGI V4.32 release gate: run manually before certification.
// Expected to FAIL on rc.1 until unique event identity is implemented in
// the shared core AND both offline-embedded HTML copies.
import fs from 'node:fs';
import vm from 'node:vm';
const code=fs.readFileSync(new URL('../sagi-signature-core-v432.js',import.meta.url),'utf8');
const scope={};scope.globalThis=scope;
vm.runInNewContext(code,scope);
const core=scope.SAGISignatureCore;
function assert(condition,message){if(!condition)throw new Error(message)}
const sameMetadata={type:'GOAL',side:'HOME',team:'HOME',at:'',player:null};
const first={...sameMetadata,eventId:'match-42-event-100'};
const second={...sameMetadata,eventId:'match-42-event-101'};
assert(core.eventKey(first)!==core.eventKey(second),
  'BLOCK RELEASE: two real goals with identical metadata must not collapse');
assert(core.eventKey(first)===core.eventKey({...first}),
  'BLOCK RELEASE: retransmitted eventId must remain idempotent');
const seqA={...sameMetadata,sequence:100};
const seqB={...sameMetadata,sequence:101};
assert(core.eventKey(seqA)!==core.eventKey(seqB),
  'BLOCK RELEASE: distinct sequence numbers must not collapse');
const normalized=core.normalizeEvent(first);
assert(normalized.eventId==='match-42-event-100',
  'BLOCK RELEASE: normalization must preserve bounded eventId');
const noIdentity=core.eventKey(sameMetadata);
assert(noIdentity==='',
  'BLOCK RELEASE: metadata-only legacy events must not be treated as reliable identity');
const control=fs.readFileSync(new URL('../v45-lan.html',import.meta.url),'utf8');
assert(control.includes("function mdNextEventIdentity(type='EVENT')"),
  'BLOCK RELEASE: control source must generate persistent in-match event identity');
assert(control.includes("...mdNextEventIdentity(type)")&&control.includes("...mdNextEventIdentity('SUB')")&&control.includes("...mdNextEventIdentity('MVP')"),
  'BLOCK RELEASE: live event creators must attach explicit identity');
assert(/eventSequence\)\|\|0\)\+1/.test(control),
  'BLOCK RELEASE: event sequence must advance from persisted matchday state');
console.log('V4.32 EVENT IDENTITY GATE PASS');
