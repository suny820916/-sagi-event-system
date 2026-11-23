import fs from 'node:fs';
function assert(ok,msg){if(!ok)throw new Error(msg)}
const control=fs.readFileSync(new URL('../v45-lan.html',import.meta.url),'utf8');
const output=fs.readFileSync(new URL('../vmix-v45-lan.html',import.meta.url),'utf8');
const bat=fs.readFileSync(new URL('../SAGI_VMIX_LAN_V432_SIGNATURE_RC.bat',import.meta.url),'utf8');
const historicalBuild='SAGI432_SIGNATURE_RC3';

function buildNumber(html){
 const m=String(html).match(/SAGI4(\d{2})_[A-Z0-9_]+/);
 return m?Number(m[1]):0
}
assert(buildNumber(control)>=32,'current control regressed below V4.32');
assert(buildNumber(output)>=32,'current output regressed below V4.32');

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
 "loadMatchProjectById(remoteActive,{publishSelection:false,remoteSync:true})"
]) assert(control.includes(token),'current control lost certified V4.32 capability: '+token);

for(const token of [
 'SAGISignatureCore',
 'function introStateAllowed',
 'lastRenderedSignatureEventKey',
 "fetch('/vmix?graphicsBuild='",
 'sagiBrandA',
 '#ff1a1a',
 '#e33440'
]) assert(output.includes(token),'current output lost certified V4.32 capability: '+token);

assert(output.includes('SAGISignatureCore.eventKey(e)'),'current output lost event idempotency guard');
assert(!output.includes("fetch('/?graphicsBuild='"),'output/control version reload regression');
assert(!output.includes('opacity:.82,offset:.28'),'white flash regression');
assert(output.includes('transform-origin:0 0;opacity:0'),'first-frame transparency regression');

const ids=['mmEventSide','mmEventPlayer','mmGoalMacro','mmGenerateReplay','mmReplay','mmGoalPlayer','mmReturnLive','mmUndoEvent','mmClearEvent'];
for(const id of ids){
 const count=(control.match(new RegExp('id="'+id+'"','g'))||[]).length;
 assert(count===1,'duplicate/missing certified control id '+id+': '+count);
}

// Historical V4.32 package is immutable and self-contained even while current source advances.
const lines=bat.split(/\r?\n/),c=lines.indexOf('###SAGI_CONTROL###'),o=lines.indexOf('###SAGI_OUTPUT###');
assert(c>0&&o>c,'V4.32 BAT payload markers invalid');
const embeddedControl=lines.slice(c+1,o).join('\n').trim().replace(/\r/g,'');
const embeddedOutput=lines.slice(o+1).join('\n').trim().replace(/\r/g,'');
assert(embeddedControl.includes(historicalBuild),'historical V4.32 BAT control fingerprint missing');
assert(embeddedOutput.includes(historicalBuild),'historical V4.32 BAT output fingerprint missing');
for(const token of ['SAGISignatureCore',"function mdNextEventIdentity(type='EVENT')",'LIVE FLOW · 比赛事件主链','REPLAY_STINGER_SWITCH_MS=920','SAGI_MATCH_PROJECTS_V2','window.sagiProjectSyncDiagnostic'])assert(embeddedControl.includes(token),'historical V4.32 BAT control capability missing: '+token);
for(const token of ['SAGISignatureCore','lastRenderedSignatureEventKey','function introStateAllowed','sagiBrandA'])assert(embeddedOutput.includes(token),'historical V4.32 BAT output capability missing: '+token);
assert(bat.includes(historicalBuild),'V4.32 BAT build fingerprint missing');
assert(bat.includes('"BrowserReload"'),'V4.32 BAT BrowserReload allowlist missing');
assert(bat.includes('"ReplayPlayLastEventToOutput"'),'V4.32 BAT replay latest-only allowlist missing');
assert(bat.includes('activeProjectId'),'V4.32 BAT active project SSOT missing');
assert(bat.includes('$candidate -le $PreferredPort'),'V4.32 BAT must lock preferred port / prevent silent 8101 fallback');

// Preserve V4.32 RC7 Bridge-authoritative recovery in every later candidate.
for(const token of [
 "liveAuthority:'BRIDGE'",
 'STALE_QUEUED_FIXTURE_DROPPED',
 '本次操作未提交 · 已恢复 Bridge 直播真源',
 'LAN_TIMEOUT', 'mdConsistencyBusySince', 'busyResets'
]) assert(control.includes(token),'V4.32 RC7 Bridge recovery regression: '+token);
assert(control.includes("return{ok:false,attempts:i+1,recovered:true,conflict:true}"),'Bridge 409 conflict must not be acknowledged as committed');
assert(control.includes("async function mdScore(side,delta)")&&control.includes("const result=await publishMatchday(null);"),'score must await Bridge acknowledgement');
assert(!control.includes("mdLastConsistencyState='LOCAL_REVISION_AHEAD'"),'per-device revision must not override Bridge');

console.log('SAGI V4.32 FORWARD-COMPAT CERTIFICATION GATE PASS');
