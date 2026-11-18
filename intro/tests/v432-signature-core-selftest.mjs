import fs from 'node:fs';
import vm from 'node:vm';
function assert(ok,msg){if(!ok)throw new Error(msg)}
const code=fs.readFileSync(new URL('../sagi-signature-core-v432.js',import.meta.url),'utf8');
const sandbox={};sandbox.globalThis=sandbox;
vm.runInNewContext(code,sandbox,{filename:'sagi-signature-core-v432.js'});
const c=sandbox.SAGISignatureCore;
assert(c&&c.VERSION==='4.32.0-rc.2','core version missing');
assert(c.TOKENS.gold==='#d8b55b'&&c.TOKENS.yellow==='#f2d536'&&c.TOKENS.red==='#e33440','signature palette drift');
assert(c.normalizeEvent(null)===null,'null event must stay null');
assert(c.eventKey({type:'GOAL',sequence:1})==='','sequence without fixture must not dedupe');
assert(c.eventKey({type:'GOAL',sequence:1,fixtureKey:'A'})!==c.eventKey({type:'GOAL',sequence:1,fixtureKey:'B'}),'fixture sequence collision');
const sub=c.normalizeEvent({type:'SUBSTITUTION',side:'AWAY',team:'A',on:{id:'2',name:'IN'},off:{id:'9',name:'OUT'}});
assert(sub.type==='SUB'&&sub.side==='AWAY'&&sub.on.name==='IN'&&sub.off.name==='OUT','substitution normalization failed');
const bad=c.normalizeEvent({type:'DROP_TABLE',side:'HOME'});
assert(bad.type==='CLEAR_EVENT'&&bad.__rejectedType==='DROP_TABLE','unknown event must fail closed');
const yellow=c.normalizeEvent({type:'YELLOW',side:'HOME',player:{name:'P'}});
const red=c.normalizeEvent({type:'RED',side:'HOME',player:{name:'P'}});
assert(c.eventAccent(yellow,{homeColor:'#123456'})==='#f2d536','yellow inherited team color');
assert(c.eventAccent(red,{homeColor:'#123456'})==='#e33440','red inherited team color');
const goal=c.normalizeEvent({type:'GOAL',side:'AWAY',team:'Away',player:{name:'Striker'}});
assert(c.eventAccent(goal,{awayColor:'#13579b'})==='#13579b','goal team accent failed');
assert(c.holdMs('GOAL')===5600&&c.holdMs('SUB')===6500&&c.holdMs('FULL_TIME')===9000,'hold timing drift');
// Regression: valid zero sequence must remain usable, while unsafe identities are rejected.
const seqZero=c.normalizeEvent({type:'GOAL',fixtureKey:'fixture-zero',sequence:0,eventId:''});
assert(seqZero.sequence===0&&c.eventKey(seqZero)==='seq|fixture-zero|0','zero sequence identity lost');
assert(c.normalizeEvent({type:'GOAL',sequence:-1}).sequence===null,'negative sequence accepted');
assert(c.normalizeEvent({type:'GOAL',sequence:1.5}).sequence===null,'fractional sequence accepted');
assert(c.normalizeEvent({type:'GOAL',sequence:Number.MAX_SAFE_INTEGER+1}).sequence===null,'unsafe sequence accepted');
assert(c.normalizeType('YELLOW_CARD')==='YELLOW'&&c.normalizeType('RED_CARD')==='RED','referee card aliases regressed');
assert(c.eventAccent({type:'RED',side:'AWAY'},{awayColor:'#00ff00'})===c.TOKENS.red,'referee red card confused with team/brand color');
const replay=c.normalizeEvent({type:'REPLAY_STINGER',phase:'weird'});
assert(replay.phase==='IN'&&replay.title==='INSTANT REPLAY','replay phase fail-safe failed');
const long=c.normalizeEvent({type:'GOAL',team:'X'.repeat(500),player:{name:'Y'.repeat(500),photo:'z'.repeat(5000)}});
assert(long.team.length<=80&&long.player.name.length<=80&&long.player.photo.length<=2048,'payload bounds failed');
assert(c.eventKey({type:'GOAL',side:'HOME',team:'HOME',at:'',player:null})==='','legacy metadata must not be treated as reliable event identity');
const control=fs.readFileSync(new URL('../v45-lan.html',import.meta.url),'utf8');
const output=fs.readFileSync(new URL('../vmix-v45-lan.html',import.meta.url),'utf8');
for(const [name,html] of [['control',control],['output',output]]){
  assert(!html.includes('<script src="./sagi-signature-core-v432.js">'),'external Signature Core dependency breaks offline BAT: '+name);
  const match=html.match(/<script data-sagi-signature-core="v432">\s*([\s\S]*?)\s*<\/script>/);
  assert(match,'embedded Signature Core missing from '+name);
  assert(match[1].trim()===code.trim(),'embedded Signature Core drift in '+name);
  const offline={};offline.globalThis=offline;
  vm.runInNewContext(match[1],offline,{filename:name+'-embedded-core'});
  assert(offline.SAGISignatureCore?.VERSION===c.VERSION,'offline embedded core fails in '+name);
}
console.log('SAGI SIGNATURE CORE V4.32 RC PASS', {version:c.VERSION,types:c.EVENT_TYPES.length});
