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
const seqA={...sameMetadata,fixtureKey:'fixture-A',sequence:100};
const seqB={...sameMetadata,fixtureKey:'fixture-A',sequence:101};
assert(core.eventKey(seqA)!==core.eventKey(seqB),
  'BLOCK RELEASE: distinct sequence numbers must not collapse');
assert(core.eventKey({...seqA,fixtureKey:'fixture-B'})!==core.eventKey(seqA),
  'BLOCK RELEASE: sequence identity must be scoped to fixture');
const normalizedFixture=core.normalizeEvent({...sameMetadata,fixtureKey:'fixture-A',sequence:100});
assert(normalizedFixture.fixtureKey==='fixture-A','BLOCK RELEASE: normalized events must retain fixture identity');
assert(core.eventKey(normalizedFixture)===core.eventKey({...sameMetadata,fixtureKey:'fixture-A',sequence:100}),
  'BLOCK RELEASE: normalization must not destroy fixture-scoped deduplication');
assert(core.eventKey(core.normalizeEvent({...sameMetadata,fixtureKey:'fixture-B',sequence:100}))!==core.eventKey(normalizedFixture),
  'BLOCK RELEASE: normalized fixture identities must remain isolated');
assert(core.eventKey({...sameMetadata,sequence:100})==='',
  'BLOCK RELEASE: sequence-only events cannot safely dedupe without fixture identity');
const normalized=core.normalizeEvent(first);
assert(normalized.eventId==='match-42-event-100',
  'BLOCK RELEASE: normalization must preserve bounded eventId');
const noIdentity=core.eventKey(sameMetadata);
assert(noIdentity==='',
  'BLOCK RELEASE: metadata-only legacy events must not be treated as reliable identity');
const control=fs.readFileSync(new URL('../v45-lan.html',import.meta.url),'utf8');
assert(control.includes("normalizeEvent(event,{home:homeName,away:awayName,fixtureKey:mdFixtureKey()})"),
  'BLOCK RELEASE: published snapshots must carry fixture identity into normalization');
assert(control.includes("function mdNextEventIdentity(type='EVENT')"),
  'BLOCK RELEASE: control source must generate persistent in-match event identity');
assert(control.includes("const eventGateMs=type==='GOAL'?2500:1400"),
  'BLOCK RELEASE: GOAL must use strengthened accidental double-tap guard');
assert(control.includes("mdPublishRevision=Math.max(mdPublishRevision,remoteRevision)"),
  'BLOCK RELEASE: Bridge recovery must preserve publish revision continuity');
assert(control.includes("mdLastAckRevision=Math.max(mdLastAckRevision,remoteRevision)"),
  'BLOCK RELEASE: Bridge recovery must preserve ack revision continuity');
assert(control.includes('mdFixtureTakeoverOnce=false')&&control.includes('allowFixtureTakeover:!!mdFixtureTakeoverOnce'),
  'BLOCK RELEASE: controller must use one-shot explicit fixture takeover authorization');
const readyTakeoverBlock=control.slice(control.indexOf('function setMatchReady(on){'),control.indexOf('function requireMatchReady(){'));
const projectTakeoverBlock=control.slice(control.indexOf('async function loadMatchProject(){'),control.indexOf('async function createMatchProject(){'));
assert(readyTakeoverBlock.includes('mdAuthorizeFixtureTakeover()')&&projectTakeoverBlock.includes('mdAuthorizeFixtureTakeover()'),
  'BLOCK RELEASE: only explicit READY/project-load actions may authorize fixture takeover');
assert(control.includes("...mdNextEventIdentity(type)")&&control.includes("...mdNextEventIdentity('SUB')")&&control.includes("...mdNextEventIdentity('MVP')"),
  'BLOCK RELEASE: live event creators must attach explicit identity');
assert(/eventSequence\)\|\|0\)\+1/.test(control),
  'BLOCK RELEASE: event sequence must advance from persisted matchday state');
// V4.32 regression: duplicate delivery must retain identity, while two real
// events with identical display metadata must never be collapsed.
const distinctTypes=['GOAL','YELLOW','RED','SUB','HALF_TIME','FULL_TIME','MVP'];
for(const type of distinctTypes){
 const base={type,side:'HOME',team:'主队',at:'45:00',player:{id:'9',name:'球员九'}};
 const a=core.normalizeEvent({...base,eventId:'fixtureA-'+type+'-1',sequence:1});
 const retry=core.normalizeEvent({...base,eventId:'fixtureA-'+type+'-1',sequence:1});
 const b=core.normalizeEvent({...base,eventId:'fixtureA-'+type+'-2',sequence:2});
 assert(core.eventKey(a)===core.eventKey(retry),'BLOCK RELEASE: '+type+' retransmission changed event identity');
 assert(core.eventKey(a)!==core.eventKey(b),'BLOCK RELEASE: '+type+' distinct events collapsed');
 assert(a.__signatureVersion===core.VERSION,'BLOCK RELEASE: '+type+' normalization lost version');
}
const badSeq=core.normalizeEvent({type:'GOAL',sequence:-1});
assert(badSeq.sequence===null&&core.eventKey(badSeq)==='','BLOCK RELEASE: invalid sequence used as event identity');
const unsafeSeq=core.normalizeEvent({type:'GOAL',sequence:Number.MAX_SAFE_INTEGER+1});
assert(unsafeSeq.sequence===null&&core.eventKey(unsafeSeq)==='','BLOCK RELEASE: unsafe sequence used as event identity');
const bounded=core.normalizeEvent({type:'GOAL',eventId:'x'.repeat(300)});
assert(bounded.eventId.length===128&&core.eventKey(bounded).length===131,'BLOCK RELEASE: eventId payload bound failed');
assert(core.normalizeEvent({type:'UNRECOGNIZED'}).type==='CLEAR_EVENT','BLOCK RELEASE: unknown event must fail closed');
console.log('V4.32 EVENT IDENTITY GATE PASS');
