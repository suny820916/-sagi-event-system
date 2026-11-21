import fs from 'node:fs';
import vm from 'node:vm';
function assert(ok,msg){if(!ok)throw new Error(msg)}
const code=fs.readFileSync(new URL('../sagi-penalty-core-v433.js',import.meta.url),'utf8');
const box={};box.globalThis=box;vm.runInNewContext(code,box,{filename:'sagi-penalty-core-v433.js'});
const p=box.SAGIPenaltyCore;assert(p&&p.VERSION==='4.33.0-rc.1','core missing');
let s=p.normalizeState({rounds:5,firstSide:'HOME'});
let r=p.applyKick(s,{kickId:'k1',side:'HOME',result:'GOAL'});assert(r.accepted&&!r.deduped,'first kick rejected');s=r.state;
r=p.applyKick(s,{kickId:'k1',side:'HOME',result:'GOAL'});assert(r.accepted&&r.deduped&&r.state.history.length===1,'duplicate kickId not idempotent');
r=p.applyKick(s,{kickId:'k2',side:'HOME',result:'GOAL'});assert(!r.accepted&&r.reason==='WRONG_SIDE'&&r.expectedSide==='AWAY','wrong-side kick accepted');
r=p.applyKick(s,{kickId:'k2',side:'AWAY',result:'MISS'});assert(r.accepted,'away kick rejected');s=r.state;
assert(p.snapshot(s).homeGoals===1&&p.snapshot(s).awayGoals===0&&p.nextSide(s)==='HOME','score/turn drift');
const seq=[['h2','HOME','GOAL'],['a2','AWAY','MISS'],['h3','HOME','GOAL'],['a3','AWAY','MISS']];
for(const [kickId,side,result] of seq){const x=p.applyKick(s,{kickId,side,result});assert(x.accepted,'early-win sequence rejected '+kickId);s=x.state}
assert(s.finished&&s.winner==='HOME','early mathematical winner not detected');
let u=p.undo(s);assert(u.changed&&!u.state.finished&&u.state.winner==='','undo did not reopen shootout');s=u.state;
let sd=p.normalizeState({rounds:5,firstSide:'HOME'});let n=1;
for(let round=1;round<=5;round++){
 for(const side of ['HOME','AWAY']){const x=p.applyKick(sd,{kickId:'d'+n++,side,result:'GOAL'});assert(x.accepted,'draw setup failed');sd=x.state}
}
assert(!sd.finished&&p.suddenDeath(sd)&&p.currentRound(sd)===6,'sudden death not entered after tied five rounds');
let x=p.applyKick(sd,{kickId:'sd-h',side:'HOME',result:'GOAL'});assert(x.accepted,'sudden home rejected');sd=x.state;
x=p.applyKick(sd,{kickId:'sd-a',side:'AWAY',result:'MISS'});assert(x.accepted&&x.state.finished&&x.state.winner==='HOME','sudden-death winner failed');sd=x.state;
let long=p.normalizeState({rounds:5,firstSide:'HOME'});let id=0;
for(let round=0;round<14;round++){
 for(const side of ['HOME','AWAY']){const z=p.applyKick(long,{kickId:'L'+(++id),side,result:'GOAL'});assert(z.accepted,'long shootout stopped early');long=z.state}
}
assert(long.history.length===28&&!long.finished&&p.snapshot(long).currentRound===15,'shootout did not continue beyond 12 rounds');
const restored=p.normalizeState(JSON.parse(JSON.stringify(long)));assert(restored.history.length===28&&p.nextSide(restored)==='HOME','history restore changed state');
const dirty=p.normalizeState({history:[{kickId:'dup',side:'HOME',result:'GOAL'},{kickId:'dup',side:'HOME',result:'GOAL'}]});assert(dirty.history.length===1,'duplicate persisted history not normalized');
console.log('SAGI V4.33 PENALTY CORE PASS',{history:long.history.length,round:p.snapshot(long).currentRound});
