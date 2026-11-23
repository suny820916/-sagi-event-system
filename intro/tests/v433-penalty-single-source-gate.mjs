import fs from 'node:fs';
function assert(ok,msg){if(!ok)throw new Error(msg)}
const control=fs.readFileSync(new URL('../v45-lan.html',import.meta.url),'utf8');
const output=fs.readFileSync(new URL('../vmix-v45-lan.html',import.meta.url),'utf8');

for(const token of [
 "function mdPenaltyCompatView()",
 "sourceVersion='V4.33'",
 "source:'penaltyShootout'",
 "async function mdSimplePenaltyKick(side,result='GOAL'){return mdPenaltyKick(side,result)}",
 "async function mdSimplePenaltyAdd(side){return mdPenaltyKick(side,'GOAL')}",
 "async function mdSimplePenaltyMiss(side){return mdPenaltyKick(side,'MISS')}",
 "window.sagiPenaltySingleSourceDiagnostic",
 "p.visible=true",
 "mdLocalMutationDepth",
 "mdPendingPublishes>0||mdLocalMutationDepth>0"
]) assert(control.includes(token),'control single-source gate missing: '+token);

assert(control.includes("matchdayState.simplePenalty=mdPenaltyCompatView()"),'compatibility mirror must be derived from canonical state');
assert(control.includes("p.sourceVersion!=='V4.33'&&legacy"),'legacy migration must be one-way and version-gated');
assert(!control.includes("const simple=mdSimplePenaltyState(),director=mdPenaltyState(),show=!simple.visible"),'legacy simplePenalty toggle authority remains');
assert(!control.includes("simple.history=(p.history||[])"),'legacy mirror still independently mutates history');

for(const token of [
 "function gfxPenaltyView(g)",
 "source:'penaltyShootout'",
 "source:'legacy-simplePenalty'",
 "Object.prototype.hasOwnProperty.call(ps,'visible')"
]) assert(output.includes(token),'output canonical penalty gate missing: '+token);

assert(!output.includes("const raw=g&&g.simplePenalty||{},ps=g&&g.penaltyShootout||{}"),'output still mixes two live penalty sources');
assert(!output.includes("const p=raw.visible?raw:(ps.started?"),'legacy simplePenalty can still override canonical output');
assert(control.includes("const eventGateMs=type==='GOAL'?2500:1400"),
  'V4.33 must inherit V4.32 GOAL accidental double-tap protection');
assert(control.includes("recoverMatchdayFromBridge(false,{preferNewest:false,allowIdentityTakeover:true})"),
  'V4.33 must inherit Bridge-authoritative recovery after rejected stale/conflicting state');
assert(control.includes('mdFixtureTakeoverOnce=false')&&control.includes('allowFixtureTakeover:!!mdFixtureTakeoverOnce'),
  'V4.33 must inherit explicit fixture takeover protection');
console.log('SAGI V4.33 PENALTY SINGLE SOURCE GATE PASS');

const pkg=fs.readFileSync(new URL('../SAGI_VMIX_LAN_V433_PENALTY_RC.bat',import.meta.url),'utf8');
const pkgLines=pkg.split(/\r?\n/),pc=pkgLines.indexOf('###SAGI_CONTROL###'),po=pkgLines.indexOf('###SAGI_OUTPUT###');
assert(pc>0&&po>pc,'V4.33 package payload markers invalid');
const pkgControl=pkgLines.slice(pc+1,po).join('\n').trim().replace(/\r/g,'');
const pkgOutput=pkgLines.slice(po+1).join('\n').trim().replace(/\r/g,'');
assert(pkgControl===control.trim().replace(/\r/g,''),'V4.33 packaged control drift');
assert(pkgOutput===output.trim().replace(/\r/g,''),'V4.33 packaged output drift');
for(const token of ['SAGI433_PENALTY_SSOT_RC1','SAGI_MATCH_PROJECTS_V2','activeProjectId','window.sagiProjectSyncDiagnostic']) assert(pkg.includes(token),'V4.33 package lost unified-project foundation: '+token);
for(const token of [
 "$t -match 'SAGI433_PENALTY_SSOT_RC1'",
 "$t -match 'mdPenaltyCompatView'",
 "$t -match 'mdSimplePenaltyKick'",
 "$t -match 'gfxPenaltyView'",
 '$controlText -notmatch "SAGI433_PENALTY_SSOT_RC1"',
 '$outputText -notmatch "SAGI433_PENALTY_SSOT_RC1"'
]) assert(pkg.includes(token),'V4.33 installer does not enforce current-version cache/remote fingerprint: '+token);
assert(!pkg.includes("$t -match 'SAGI432_SIGNATURE_RC3'"),'V4.33 installer still accepts V4.32 control/output cache as current');

console.log('SAGI V4.33 PACKAGE PARITY + PROJECT SSOT GATE PASS');

for(const token of ['Get-FileHash -LiteralPath $env:SAGI_FB_CONTROL','Get-FileHash -LiteralPath $env:SAGI_FB_OUTPUT','$LastScoreLogSignature','$LastStateGuardLogKey','durableProbe.event = $null','FIXTURE_TAKEOVER_REQUIRED','STALE_MATCHDAY_REVISION']) assert(pkg.includes(token),'V4.33 cache integrity or inherited Bridge guard missing: '+token);
console.log('V4.33 exact cache integrity and Bridge inheritance gate PASS');

// Canonical history must survive beyond 12 rounds; the five-dot UI alone may window it.
assert(control.includes('history:(p.history||[]).map(x=>({...x}))'),'snapshot must preserve all kick history');
assert(!control.includes('history:(p.history||[]).slice(0,24)'),'snapshot truncates sudden-death history');
const {runInNewContext}=await import('node:vm');
const start=control.indexOf('function mdPenaltyState(){');
const end=control.indexOf('window.sagiPenaltySingleSourceDiagnostic',start);
assert(start>=0&&end>start,'cannot extract actual penalty functions');
const history=Array.from({length:30},(_,i)=>({side:i%2?'AWAY':'HOME',result:'GOAL',at:String(i)}));
const ctx={matchdayState:{penaltyShootout:{sourceVersion:'V4.33',started:true,visible:true,rounds:5,history},homeScore:2,awayScore:2},q:()=>({value:''})};
const snap=runInNewContext(control.slice(start,end)+'\nmdPenaltySnapshot()',ctx);
assert(snap.history.length===30&&snap.homeGoals===15&&snap.awayGoals===15,'long shootout snapshot truncated');
assert(snap.history[29].at==='29'&&snap.nextSide==='HOME','last kick or next side lost');
assert(snap.history!==history&&snap.history[0]!==history[0],'snapshot must not alias mutable history');
console.log('V4.33 15-round canonical snapshot retention PASS');

// Regression: long sudden-death sessions must remain complete and isolated across snapshots.
const extendedHistory=Array.from({length:80},(_,i)=>({side:i%2?'AWAY':'HOME',result:'GOAL',at:String(i)}));
ctx.matchdayState.penaltyShootout.history=extendedHistory;
const longSnap=runInNewContext(control.slice(start,end)+'\nmdPenaltySnapshot()',ctx);
assert(longSnap.history.length===80&&longSnap.homeGoals===40&&longSnap.awayGoals===40,
  '40-round sudden-death history truncated or incorrectly tallied');
assert(longSnap.history[79].at==='79'&&longSnap.nextSide==='HOME',
  '40-round continuation lost its next-side ordering');
longSnap.history[0].at='changed-in-snapshot';
assert(extendedHistory[0].at==='0','snapshot mutation leaked into canonical history');
console.log('V4.33 40-round sudden-death snapshot isolation PASS');


const winnerEnd=control.indexOf('function mdPenaltyDots(',start);
assert(winnerEnd>end,'cannot extract winner evaluator');
const winnerCode=control.slice(start,winnerEnd);
const winnerCtx={matchdayState:{penaltyShootout:{sourceVersion:'V4.33',started:true,visible:true,rounds:3,firstSide:'HOME',history:[
 {side:'HOME',result:'GOAL'},{side:'AWAY',result:'MISS'},
 {side:'HOME',result:'GOAL'},{side:'AWAY',result:'MISS'}
]}},q:()=>({value:''})};
const early=runInNewContext(winnerCode+'\nmdPenaltyEvaluateWinner()',winnerCtx);
assert(early==='HOME'&&winnerCtx.matchdayState.penaltyShootout.finished,
 '3-round mathematically decided winner not finalized early');
assert(winnerCtx.matchdayState.homePen===2&&winnerCtx.matchdayState.awayPen===0,
 'canonical penalty totals not synchronized after early finish');
winnerCtx.matchdayState.penaltyShootout={sourceVersion:'V4.33',started:true,visible:true,rounds:5,firstSide:'HOME',
 history:Array.from({length:12},(_,i)=>({side:i%2?'AWAY':'HOME',result:i===11?'MISS':'GOAL'}))};
const sudden=runInNewContext(winnerCode+'\nmdPenaltyEvaluateWinner()',winnerCtx);
assert(sudden==='HOME'&&winnerCtx.matchdayState.homePen===6&&winnerCtx.matchdayState.awayPen===5,
 'sudden-death winner or penalty totals incorrect');
console.log('V4.33 3-round early finish + sudden-death winner PASS');
