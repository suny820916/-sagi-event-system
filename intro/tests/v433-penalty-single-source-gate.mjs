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
console.log('SAGI V4.33 PACKAGE PARITY + PROJECT SSOT GATE PASS');
