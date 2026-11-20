import fs from 'node:fs';
function assert(ok,msg){if(!ok)throw new Error(msg)}
const control=fs.readFileSync(new URL('../v45-lan.html',import.meta.url),'utf8');
const output=fs.readFileSync(new URL('../vmix-v45-lan.html',import.meta.url),'utf8');
const bat=fs.readFileSync(new URL('../SAGI_VMIX_LAN_V432_SIGNATURE_RC.bat',import.meta.url),'utf8');
const build='SAGI432_SIGNATURE_RC3';

for(const [name,html] of [['control',control],['output',output]])assert(html.includes(build),name+' build fingerprint missing');

for(const token of [
 'LIVE FLOW · 比赛事件主链',
 'instantReplayPlayLatest',
 'REPLAY_STINGER_SWITCH_MS=920',
 "programGate:'SAGI4311_PROGRAM'",
 '完整出场结束自动清屏',
 "function mdNextEventIdentity(type='EVENT')",
 "normalizeEvent(event,{home:homeName,away:awayName,fixtureKey:mdFixtureKey()})",
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
 "fetch('/vmix?graphicsBuild='",
 'sagiBrandA',
 '#ff1a1a',
 '#e33440'
]) assert(output.includes(token),'output regression: '+token);

assert(output.includes('SAGISignatureCore.eventKey(e)'),'output event idempotency guard missing');
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
assert(embeddedControl===control.trim().replace(/\r/g,''),'BAT control payload drift');
assert(embeddedOutput===output.trim().replace(/\r/g,''),'BAT output payload drift');
assert(bat.includes(build),'BAT build fingerprint missing');
assert(bat.includes('"BrowserReload"'),'BAT BrowserReload allowlist missing');
assert(bat.includes('"ReplayPlayLastEventToOutput"'),'BAT replay latest-only allowlist missing');
assert(bat.includes('SAGI_MATCH_PROJECTS_V2'),'BAT project SSOT schema missing');
assert(bat.includes('activeProjectId'),'BAT active project authority missing');
assert(!control.includes("mdLastConsistencyState='LOCAL_REVISION_AHEAD'"),'stale per-device local revision can still overrule Bridge');
assert(bat.includes('$candidate -le $PreferredPort'),'BAT must lock preferred port / prevent silent 8101 fallback');
console.log('SAGI V4.32 CLEAN INTEGRATION GATE PASS');
