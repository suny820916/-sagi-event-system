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
 "p.visible=true"
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
