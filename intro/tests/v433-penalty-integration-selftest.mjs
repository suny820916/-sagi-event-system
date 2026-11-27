import fs from 'node:fs';
function assert(ok,msg){if(!ok)throw new Error(msg)}
const control=fs.readFileSync(new URL('../v45-lan.html',import.meta.url),'utf8');
const output=fs.readFileSync(new URL('../vmix-v45-lan.html',import.meta.url),'utf8');
const core=fs.readFileSync(new URL('../sagi-penalty-core-v433.js',import.meta.url),'utf8');
const bat=fs.readFileSync(new URL('../SAGI_VMIX_LAN_V433_PENALTY_RC.bat',import.meta.url),'utf8');
const rollback=fs.readFileSync(new URL('../SAGI_VMIX_LAN_V432_SIGNATURE_RC.bat',import.meta.url),'utf8');

assert(control.includes("SAGI433_PENALTY_RC1"),'V4.33 control fingerprint missing');
assert(control.includes('data-sagi-penalty-core="v433"'),'embedded V4.33 penalty core tag missing');
const embedded=control.match(/<script data-sagi-penalty-core="v433">\s*([\s\S]*?)\s*<\/script>/);
assert(embedded,'embedded penalty core payload missing');
assert(embedded[1].trim()===core.trim(),'embedded penalty core drift from source');

for(const token of [
  'function mdPenaltyCoreReady()',
  'function mdPenaltyCommitKick(',
  'SAGIPenaltyCore.applyKick',
  'SAGIPenaltyCore.undo',
  'mdPenaltySubmitBusy',
  '上一罚正在同步 · 请勿重复点击',
  'history:(p.history||[]).map(x=>({...x}))',
  'coreVersion:mdPenaltyCoreReady()?SAGIPenaltyCore.VERSION'
]) assert(control.includes(token),'V4.33 live control integration missing: '+token);

assert(!control.includes("history:(p.history||[]).slice(0,24)"),'penalty history is still truncated at 24 attempts');
assert(control.includes("simple.history=(p.history||[]).map(x=>({kickId:x.kickId||''"),'simple penalty mirror lost kickId linkage');
assert(control.includes("if(mdPenaltySubmitBusy){note('上一罚正在同步 · 请勿重复点击');return false}"),'rapid repeat guard missing');
assert(control.includes("if(published&&published.recovered)"),'Bridge conflict recovery not wired into penalty commit');
const startFn=control.slice(control.indexOf('async function mdPenaltyStart(){'),control.indexOf('async function mdPenaltyKick(',control.indexOf('async function mdPenaltyStart(){')));
assert(startFn.indexOf('await publishMatchday(null)')>=0&&startFn.indexOf('await refreshGraphicsBrowser(false)')>startFn.indexOf('await publishMatchday(null)'),'penalty start can still be overwritten by passive Bridge sync before first commit');

const cMarker='###SAGI_CONTROL###',oMarker='###SAGI_OUTPUT###';
const lines=bat.split(/\r?\n/),ci=lines.lastIndexOf(cMarker),oi=lines.lastIndexOf(oMarker);
assert(ci>0&&oi>ci,'V4.33 BAT payload markers invalid');
const embeddedControl=lines.slice(ci+1,oi).join('\n').trim().replace(/\r/g,'');
const embeddedOutput=lines.slice(oi+1).join('\n').trim().replace(/\r/g,'');
assert(embeddedControl===control.trim().replace(/\r/g,''),'V4.33 BAT control payload drift');
assert(embeddedOutput===output.trim().replace(/\r/g,''),'V4.33 BAT output payload drift');
assert(bat.includes('V4.33 PENALTY RC'),'V4.33 BAT title missing');
assert(bat.includes('SAGI433_PENALTY_RC1')&&bat.includes('SAGIPenaltyCore'),'V4.33 BAT control validation missing');

const ps=lines.lastIndexOf('###SAGI_PS###');
assert(ps>0&&ps<ci,'V4.33 BAT PowerShell payload marker invalid');
const bridge=lines.slice(ps+1,ci).join('\n');
const firstRequest=bridge.search(/^\s*Invoke-WebRequest\b/m);
const progress=bridge.indexOf('$ProgressPreference = "SilentlyContinue"');
assert(firstRequest>=0&&progress>=0&&progress<firstRequest,'blue progress-bar hotfix is not inherited by V4.33');

assert(rollback.includes('SAGI432_SIGNATURE_RC7'),'V4.32 rollback package fingerprint missing');
assert(!rollback.includes('SAGI433_PENALTY_RC1'),'V4.32 rollback package was contaminated by V4.33');
assert(output.includes('id="simplePenaltyBoard"'),'live output penalty board missing');

console.log('SAGI V4.33 PENALTY INTEGRATION PASS',{
  build:'SAGI433_PENALTY_RC1',
  controlBytes:Buffer.byteLength(control),
  outputBytes:Buffer.byteLength(output)
});

assert(!control.includes('all.slice(-5)'),'director dots truncated');
assert(!control.includes('length:Math.min(5,slots)'),'director dots capped');
assert(!output.includes('attempts.slice(-5)'),'output dots truncated');
assert(!output.includes('length:Math.min(12,total)'),'output dots capped');
assert(control.includes('<title>SAGI V4.33 RC'),'wrong RC title');

const loadProjectFn=control.slice(control.indexOf('async function loadMatchProjectById('),control.indexOf('async function loadMatchProject(){'));
assert(loadProjectFn.includes('await mdPublishChain'),'project switch does not drain previous fixture writes');
assert(loadProjectFn.indexOf('await publishMatchday(null)')>0&&loadProjectFn.indexOf('await publishMatchday(null)')<loadProjectFn.indexOf('await persistMatchProjectsBridge(getMatchProjects(),id)'),'project selection advertised before live fixture commit');
assert(control.includes('persistMatchProjectsBridge(merged,remoteActive)'),'legacy project migration drops active selection');


for(const token of [
  'CLIENT_ABORTED_REQUEST_BODY',
  'REQUEST_BODY_TIMEOUT',
  '$stream.ReadTimeout = 700',
  '$bodyDeadline = [DateTime]::UtcNow.AddMilliseconds(2200)',
  '"unchanged":true',
  '$existingCanonical -eq $canonicalPayload',
  'SAGI V4.33 PENALTY RC - MATCH SAFE LAN DIRECT',
  'appVersion="4.33-penalty-rc"',
  'bridgeVersion="4.7.2"'
]) assert(bat.includes(token),'V4.33 LAN transport hardening missing: '+token);
assert(!bat.includes('SAGI V4.7.2 MATCH SAFE LAN DIRECT - vMix Bridge'),'ambiguous old Bridge banner still visible');
assert(!bat.includes('version="4.7.0";mode="MATCH_MODE"'),'stale health version still advertised');


for(const token of [
  'lastLatencyMs:0',
  'maxLatencyMs:0',
  'totalLatencyMs:0',
  'samples:0',
  "Number.isFinite(r.latencyMs)?' · '+r.latencyMs+'ms':'')"
]) assert(control.includes(token),'V4.33 LAN latency instrumentation missing: '+token);
for(const token of [
  'let outputPollBusy=false,outputPollQueued=false;',
  'if(outputPollBusy){outputPollQueued=true;return false}',
  'setInterval(poll,250)'
]) assert(output.includes(token),'V4.33 low-latency output polling missing: '+token);
assert(!output.includes('setInterval(poll,650)'),'legacy 650ms vMix polling interval still active');

assert(control.includes("setInterval(()=>{mdConsistencyCheck(false).catch(()=>{})},350)"),'controller Bridge-follow polling is not 350ms');
assert(!control.includes("setInterval(()=>{mdConsistencyCheck(false).catch(()=>{})},900)"),'legacy 900ms controller Bridge-follow polling still active');

const syncImpl=control.match(/let mdConsistencyEpoch=0;[\s\S]*?(?=\nasync function mdRecoverySync)/)?.[0];
assert(syncImpl,'production sync implementation missing');
const makePollHarness=new Function('requests',`
 let time=100,mdConsistencyBusy=false,mdConsistencyBusySince=0,projectLoadBusy=false,mdPendingPublishes=0;
 let mdLastConsistencyState='',mdLastConsistencyAt=0;
 const Date={now:()=>time},mdRecoveryMetrics={busyResets:0,passivePolls:0,lanTimeouts:0};
 const lanJson=()=>new Promise((resolve,reject)=>requests.push({resolve,reject}));
 const mdBridgeMatchesCurrent=()=>false;
 ${syncImpl}
 return {poll:mdConsistencyCheck,advance:()=>{time+=4500},state:()=>({busy:mdConsistencyBusy,status:mdLastConsistencyState})};
`);
for(const staleFailure of [false,true]){
 const requests=[],h=makePollHarness(requests);
 const stale=h.poll(true);h.advance();const current=h.poll(true);
 assert(requests.length===2,'watchdog did not replace expired poll');
 if(staleFailure)requests[0].reject(new Error('LAN_TIMEOUT'));else requests[0].resolve({commandId:'old'});
 await stale;
 assert(h.state().busy&&h.state().status==='','stale completion changed current lock or status');
 assert(await h.poll(true)===false&&requests.length===2,'stale completion allowed another concurrent poll');
 requests[1].resolve(null);await current;
 assert(!h.state().busy&&h.state().status==='BRIDGE_EMPTY','replacement poll did not release its own lock');
}
console.log('PASS stale passive polls cannot release or overwrite a replacement poll');

const applyImpl=output.match(/function applyGraphics\(g\)\{[\s\S]*?(?=\r?\n\r?\nwindow.sagiScoreCenterDiagnostic)/)?.[0];
assert(applyImpl,'output applyGraphics function missing');
const outputHarness=new Function(`
 let currentGraphics=null,frozenGraphics=null,lastGraphicsFixtureKey='',lastGraphicsRevision=0;
 let cleanups=0,lastRenderedSignatureEventKey='';
 const outputHealth={},gfxSeconds=g=>g.clock.baseSeconds+3,updateScoreBug=()=>{},hideEvent=()=>{cleanups++},showEvent=g=>{if(g.event)lastRenderedSignatureEventKey=g.event.id;};
 ${applyImpl}
 return {apply:applyGraphics, snapshot:()=>frozenGraphics,visuals:()=>[cleanups,lastRenderedSignatureEventKey]};
`)();
const fixtureOne={fixtureKey:'fixture-one',revision:20,homeScore:3,event:{id:'old-goal'},scoreboardFrozen:true,clock:{baseSeconds:120,running:true}};
const fixtureTwo={fixtureKey:'fixture-two',revision:1,homeScore:0,scoreboardFrozen:true,clock:{baseSeconds:5,running:true}};
outputHarness.apply(fixtureOne);
assert(outputHarness.snapshot().clock.baseSeconds===123&&!outputHarness.snapshot().clock.running,'initial freeze did not capture clock');
outputHarness.apply(fixtureTwo);
assert(JSON.stringify(outputHarness.visuals())==='[1,""]','old fixture animation or event identity survived switch');
assert(outputHarness.snapshot().fixtureKey===fixtureTwo.fixtureKey&&outputHarness.snapshot().homeScore===0&&outputHarness.snapshot().clock.baseSeconds===8,'frozen output retained previous fixture');
outputHarness.apply({...fixtureTwo,revision:2,homeScore:1,clock:{baseSeconds:90,running:true}});
assert(outputHarness.visuals()[0]===1,'same-fixture update cleared event visuals');
assert(outputHarness.snapshot().homeScore===0&&outputHarness.snapshot().clock.baseSeconds===8,'same-fixture freeze drifted');
assert(outputHarness.apply({...fixtureTwo,revision:1,scoreboardFrozen:false})===false&&!!outputHarness.snapshot(),'stale update unfroze output');
outputHarness.apply({...fixtureTwo,revision:3,scoreboardFrozen:false});
assert(outputHarness.snapshot()===null,'unfreeze failed to clear snapshot');
console.log('PASS frozen scoreboard switches fixtures without leaking the previous clock or score');
