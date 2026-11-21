import fs from 'node:fs';
function assert(ok,msg){if(!ok)throw new Error(msg)}
const control=fs.readFileSync(new URL('../v45-lan.html',import.meta.url),'utf8');
const output=fs.readFileSync(new URL('../vmix-v45-lan.html',import.meta.url),'utf8');
const bat=fs.readFileSync(new URL('../SAGI_VMIX_LAN_V432_SIGNATURE_RC.bat',import.meta.url),'utf8');
const build='SAGI432_SIGNATURE_RC7';

for(const [name,html] of [['control',control],['output',output]])assert(html.includes(build),name+' build fingerprint missing');

for(const token of [
 'LIVE FLOW · 比赛事件主链',
 'instantReplayPlayLatest',
 'REPLAY_STINGER_SWITCH_MS=920',
 "programGate:'SAGI4311_PROGRAM'",
 '完整出场结束自动清屏',
 "function mdNextEventIdentity(type='EVENT')",
 "normalizeEvent(event,{home:homeName,away:awayName,fixtureKey:mdFixtureKey()})",
 "safePhoto",
 "SAGI_MATCH_PROJECTS_V2",
 "window.sagiProjectSyncDiagnostic",
 "loadMatchProjectById(remoteActive,{publishSelection:false,remoteSync:true})",
 "liveAuthority:'BRIDGE'",
 "Revisions are not comparable across independent browser controllers. Bridge is the live authority."
]) assert(control.includes(token),'control regression: '+token);

for(const token of [
 'SAGISignatureCore',
 'function introStateAllowed',
 'lastRenderedSignatureEventKey',
 'function setEventPhoto',
 "fetch('/vmix?graphicsBuild='",
 'sagiBrandA',
 '#ff1a1a',
 '#e33440'
]) assert(output.includes(token),'output regression: '+token);

assert(output.includes('SAGISignatureCore.eventKey(e)'),'output event idempotency guard missing');
assert(control.includes("photo:p.photo||''"),'GOAL/control event no longer carries the selected player photo');
assert(output.includes("setEventPhoto(e.player.photo)"),'GOAL output is not using SAFE MODE player-photo rendering');
assert(output.includes("photo.onerror=()=>{wrap.classList.remove('on');photo.removeAttribute('src')}"),'broken player photo can leave an empty event-photo panel on air');
for(const [name,html] of [['control',control],['output',output]]){
  const scripts=[...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)].map(x=>x[1]);
  for(let i=0;i<scripts.length;i++){
    try{new Function(scripts[i])}catch(e){throw new Error(name+' inline script '+i+' syntax error: '+e.message)}
  }
}
assert(!output.includes("fetch('/?graphicsBuild='"),'output/control version reload regression');
assert(!output.includes('opacity:.82,offset:.28'),'white flash regression');
assert(output.includes('transform-origin:0 0;opacity:0'),'first-frame transparency regression');

const ids=['mmEventSide','mmEventPlayer','mmGoalMacro','mmGenerateReplay','mmReplay','mmGoalPlayer','mmReturnLive','mmUndoEvent','mmClearEvent'];
for(const id of ids){
 const count=(control.match(new RegExp('id="'+id+'"','g'))||[]).length;
 assert(count===1,'duplicate/missing critical control id '+id+': '+count);
}

const lines=bat.split(/\r?\n/),c=lines.indexOf('###SAGI_CONTROL###'),o=lines.indexOf('###SAGI_OUTPUT###');
assert(c>0&&o>c,'BAT payload markers invalid');
const embeddedControl=lines.slice(c+1,o).join('\n').trim().replace(/\r/g,'');
const embeddedOutput=lines.slice(o+1).join('\n').trim().replace(/\r/g,'');
const isV433=control.includes('SAGI433_PENALTY_RC1');
if(isV433){
 assert(embeddedControl.includes(build),'frozen V4.32 rollback control fingerprint missing');
 assert(!embeddedControl.includes('SAGI433_PENALTY_RC1'),'V4.32 rollback BAT contaminated by V4.33 control');
}else{
 assert(embeddedControl===control.trim().replace(/\r/g,''),'BAT control payload drift');
}
assert(embeddedOutput===output.trim().replace(/\r/g,''),'BAT output payload drift');
assert(bat.includes(build),'BAT build fingerprint missing');
assert(bat.includes('"BrowserReload"'),'BAT BrowserReload allowlist missing');
assert(bat.includes('"ReplayPlayLastEventToOutput"'),'BAT replay latest-only allowlist missing');
assert(bat.includes('SAGI_MATCH_PROJECTS_V2'),'BAT project SSOT schema missing');
assert(bat.includes('activeProjectId'),'BAT active project authority missing');
assert(!control.includes("mdLastConsistencyState='LOCAL_REVISION_AHEAD'"),'stale per-device local revision can still overrule Bridge');
assert(bat.includes('$candidate -le $PreferredPort'),'BAT must lock preferred port / prevent silent 8101 fallback');
assert(control.includes("STALE_QUEUED_FIXTURE_DROPPED"),'stale queued fixture publish is not dropped after Bridge authority recovery');
assert(control.includes("return{ok:false,attempts:i+1,recovered:true,conflict:true}"),'409 fixture conflict is still reported as a successful Bridge commit');
assert(control.includes("本次操作未提交 · 已恢复 Bridge 直播真源"),'operator UI does not expose Bridge conflict recovery');
assert(control.includes("async function mdScore(side,delta)")&&control.includes("const result=await publishMatchday(null);"),'score control can still report optimistic local success before Bridge acknowledgement');
assert(control.includes("LAN_TIMEOUT")&&control.includes("mdConsistencyBusySince")&&control.includes("busyResets"),'mobile passive Bridge-follow can still hang forever on a stuck LAN request');
assert(bat.includes("$LastScoreLogSignature")&&bat.includes("$scoreLogSignature -ne $LastScoreLogSignature"),'Bridge still logs every duplicate score POST and can flash the console');
assert(bat.includes("$LastStateGuardLogKey")&&bat.includes("TotalSeconds -ge 2"),'Bridge state-guard log spam is not rate-limited');
assert(bat.includes("aborted by the software in your host machine"),'normal host-side socket abort still surfaces as LAN WARN');
assert(!bat.includes("SAGI432_SIGNATURE_RC3"),'embedded updater still accepts obsolete RC3 fingerprint');
assert(control.includes("err.status=r.status")&&control.includes("err.code=body&&body.error||''"),'LAN HTTP errors do not expose structured 409 reason');
assert(bat.includes("$benignDisconnect")&&bat.includes("Unable to read data from the transport connection"),'expected browser/socket disconnect noise is not filtered');
const bridgeStart=bat.indexOf('###SAGI_PS###');
const bridgeText=bat.slice(bridgeStart);
const firstWebRequestMatch=bridgeText.match(/^\s*Invoke-WebRequest\b/m);
const firstWebRequest=firstWebRequestMatch?bridgeStart+firstWebRequestMatch.index:-1;
const globalProgressSilence=bat.indexOf('$ProgressPreference = "SilentlyContinue"',bridgeStart);
assert(firstWebRequest>bridgeStart&&globalProgressSilence>bridgeStart&&globalProgressSilence<firstWebRequest,'PowerShell web-request progress UI is not globally suppressed before live Bridge requests');
console.log('SAGI V4.32 CLEAN INTEGRATION GATE PASS',{rollbackFrozen:isV433});
