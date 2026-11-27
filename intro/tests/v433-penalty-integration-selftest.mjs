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
 let cleanups=0,lastRenderedSignatureEventKey='',lastHomeScore=2,lastAwayScore=1;
 const clearedRolls=[],q=id=>({classList:{remove:cls=>clearedRolls.push([id,cls])}});
 const outputHealth={},gfxSeconds=g=>g.clock.baseSeconds+3,updateScoreBug=()=>{},hideEvent=()=>{cleanups++},showEvent=g=>{if(g.event)lastRenderedSignatureEventKey=g.event.id;};
 ${applyImpl}
 return {apply:applyGraphics, snapshot:()=>frozenGraphics,visuals:()=>[cleanups,lastRenderedSignatureEventKey], scoreMotion:()=>[lastHomeScore,lastAwayScore,clearedRolls.length]};
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
assert(JSON.stringify(outputHarness.scoreMotion())==='[null,null,4]','fixture switch retained old score animation state');
assert(outputHarness.snapshot().homeScore===0&&outputHarness.snapshot().clock.baseSeconds===8,'same-fixture freeze drifted');
assert(outputHarness.apply({...fixtureTwo,revision:1,scoreboardFrozen:false})===false&&!!outputHarness.snapshot(),'stale update unfroze output');
outputHarness.apply({...fixtureTwo,revision:3,scoreboardFrozen:false});
assert(outputHarness.snapshot()===null,'unfreeze failed to clear snapshot');
console.log('PASS frozen scoreboard switches fixtures without leaking the previous clock or score');

const readerImpl=output.match(/const OUTPUT_REQUEST_TIMEOUT_MS=[\s\S]*?(?=\r?\nconst q=)/)?.[0];
assert(readerImpl,'output request implementation missing');
let expire, pendingTimer, requestedUrl;
let stallBody=true;
const outputReader=new Function('fetch','setTimeout','clearTimeout',`
 ${readerImpl}
 return {lanState,lanMatchday};
`)(
 async (url,{signal})=>{
  requestedUrl=url;
  const stall=()=>new Promise((resolve,reject)=>{
   signal.addEventListener('abort',()=>reject(new Error('aborted')),{once:true});
  });
  return stallBody?{ok:true,json:stall}:url==='/api/state'?stall():{ok:true,json:async()=>({revision:7})};
 },
 (callback,delay)=>{assert(delay===2000,'unexpected output request timeout');expire=callback;return pendingTimer=Symbol();},
 timer=>{assert(timer===pendingTimer,'wrong output request timer cleared');pendingTimer=null;}
);
const stalledBody=outputReader.lanMatchday();
await Promise.resolve();
assert(requestedUrl.startsWith('/api/matchday?ts='),'wrong matchday endpoint');
expire();
await stalledBody.then(()=>assert(false,'stalled response body did not reject'),error=>assert(error.message==='aborted','wrong body error'));
assert(pendingTimer===null,'timer survived aborted response body');
stallBody=false;
const stalledState=outputReader.lanState();
assert(requestedUrl==='/api/state','wrong lineup state endpoint');
expire();
await stalledState.then(()=>assert(false,'stalled request did not reject'),error=>assert(error.message==='aborted','wrong request error'));
assert(pendingTimer===null,'timer survived aborted request');
assert((await outputReader.lanMatchday()).revision===7&&pendingTimer===null,'output failed to read fresh state after timeouts');
console.log('PASS output request deadlines cover headers and JSON bodies and allow recovery');

const undoImpl=control.match(/function mdUndoLast\(\)\{[\s\S]*?(?=\r?\nasync function mdScore)/)?.[0];
assert(undoImpl,'event undo implementation missing');
const undoEvent=new Function('matchdayState',`
 const mdRenderLog=()=>{},mdRenderMarkers=()=>{},q=()=>({}),note=()=>{},mdEventLabel=e=>e.type,publishMatchday=()=>{};
 ${undoImpl}
 return mdUndoLast;
`);
const events={eventLog:[
 {event:{type:'GOAL',replayMarkerEventId:'missing'}},
 {event:{type:'GOAL',replayMarkerEventId:'exact'}},
 {event:{type:'GOAL',eventId:'legacy'}}
],replayMarkers:[{type:'GOAL',eventId:'newer'},{type:'GOAL',eventId:'exact'},{type:'GOAL'}]};
const undo=undoEvent(events);
undo();
assert(events.replayMarkers.length===3,'undo with a missing marker removed an unrelated marker');
undo();
assert(events.replayMarkers.length===2&&events.replayMarkers[0].eventId==='newer'&&!events.replayMarkers[1].eventId,'undo did not remove the exact linked marker');
undo();
assert(events.replayMarkers.length===1&&events.replayMarkers[0].eventId==='newer','legacy undo removed a linked marker');
console.log('PASS event undo removes only its own replay marker and supports legacy records');

const subImpl=control.match(/function mdSubstitutionByIds\(side,offId,onId\)\{[\s\S]*?(?=\r?\nfunction mdSubstitution)/)?.[0];
assert(subImpl,'substitution implementation missing');
const subHarness=new Function(`
 let calls=0,sent=0;
 const matchdayState={},q=()=>({}),note=()=>{},mdRecordEvent=()=>{},mdFormat=()=>'',mdNowSeconds=()=>0,mdNextEventIdentity=()=>({});
 const mdPlayer=(side,id)=>side==='HOME'&&['p1','p2'].includes(id)?{id}:null;
 const mdAcceptOperatorEvent=()=>++calls===1,gdRunEvent=()=>{sent++};
 ${subImpl}
 return {submit:mdSubstitutionByIds,counts:()=>[calls,sent]};
`)();
assert(subHarness.submit('AWAY','p1','p2')===false,'foreign players accepted');
assert(subHarness.submit('HOME','p1','p1')===false,'same-player substitution accepted');
assert(subHarness.submit('HOME','','p2')===false,'missing outgoing player accepted');
assert(JSON.stringify(subHarness.counts())==='[0,0]','invalid substitution consumed the duplicate guard');
subHarness.submit('HOME','p1','p2');
assert(subHarness.submit('HOME','p1','p2')===false&&JSON.stringify(subHarness.counts())==='[2,1]','valid substitution or duplicate handling failed');
console.log('PASS desktop and mobile substitution share roster and duplicate validation');

const directorImpl=control.match(/async function gdRunEvent\(ev,holdMs=5200\)\{[\s\S]*?(?=\r?\nfunction ssPersist)/)?.[0];
assert(directorImpl,'graphics director implementation missing');
const directorHarness=new Function(`
 let gdSequence=0,mdMacroSeq=0,mdMacroTimer,releaseOverlay,releaseWrite,delay='',clears=0;
 const writes=[],timers=[],cameraTimers=[];
 const graphicsDirectorSettings={enabled:true,autoReplay:true},matchReady=true;
 const sdRecommend=()=>{},gdClearTimers=()=>{},gdClearCameraTimers=()=>{},gdSetStatus=()=>{};
 const gdEnsureOverlay=()=>delay==='overlay'?new Promise(r=>{releaseOverlay=r}):Promise.resolve();
 const publishMatchday=e=>{writes.push(e?.type||'SCORE');return delay==='write'?new Promise(r=>{releaseWrite=r}):Promise.resolve();};
 const gdSchedule=fn=>timers.push(fn),gdScheduleCamera=fn=>cameraTimers.push(fn);
 const cameraSlotForRole=()=> 'replay',vdSlotAvailable=()=>true,REPLAY_STINGER_SWITCH_MS=920;
 const mdEventAutoClear=()=>{clears++};
 ${directorImpl}
 return {run:gdRunEvent,delay:value=>delay=value,supersede:()=>gdSequence++,releaseOverlay:()=>releaseOverlay(),releaseWrite:()=>releaseWrite(),counts:()=>[writes.length,timers.length,cameraTimers.length,clears]};
`)();
directorHarness.delay('overlay');
const oldOverlayEvent=directorHarness.run({type:'GOAL'});
directorHarness.supersede();
directorHarness.releaseOverlay();
await oldOverlayEvent;
assert(JSON.stringify(directorHarness.counts())==='[0,0,0,0]','superseded overlay completion published a stale event');
directorHarness.delay('write');
const oldScoreEvent=directorHarness.run({type:'GOAL'});
await Promise.resolve();
directorHarness.supersede();
directorHarness.releaseWrite();
await oldScoreEvent;
assert(JSON.stringify(directorHarness.counts())==='[1,0,0,0]','superseded score completion scheduled stale goal or replay timers');
const oldCardEvent=directorHarness.run({type:'YELLOW'});
await Promise.resolve();
directorHarness.supersede();
directorHarness.releaseWrite();
await oldCardEvent;
assert(JSON.stringify(directorHarness.counts())==='[2,0,0,0]','superseded card completion scheduled an event clear');
console.log('PASS delayed graphics director completions cannot schedule stale actions');

const repeatImpl=control.match(/function mdAcceptOperatorEvent\(signature,windowMs=850\)\{[\s\S]*?(?=\r?\nasync function mdPostMatchdayWithRetry)/)?.[0];
assert(repeatImpl,'operator duplicate guard missing');
const repeatHarness=new Function(`
 let now=100,fixtureKey='one';
 const mdRecentOperatorEvents=new Map(),performance={now:()=>now},q=()=>({}),mdFixtureKey=()=>fixtureKey;
 ${repeatImpl}
 return {accept:mdAcceptOperatorEvent,fixture:value=>fixtureKey=value,tick:value=>now+=value,size:()=>mdRecentOperatorEvents.size};
`)();
assert(repeatHarness.accept('RED|HOME|p1',1400)&&repeatHarness.accept('YELLOW|AWAY|p2',1400),'distinct match events were blocked');
assert(!repeatHarness.accept('RED|HOME|p1',1400),'interleaved action bypassed repeat guard');
repeatHarness.fixture('two');
assert(repeatHarness.accept('RED|HOME|p1',1400),'prior fixture blocked a valid event');
repeatHarness.tick(1400);
assert(repeatHarness.accept('RED|HOME|p1',1400)&&repeatHarness.size()===1,'expired repeat guard entries were not cleared');
console.log('PASS interleaved operator actions deduplicate per fixture and expire');

const clockImpl=control.match(/function mdConsistencyClockDiffers\(remote,local,now\)\{[\s\S]*?(?=\r?\nfunction mdPassiveSyncActive)/)?.[0];
assert(clockImpl&&syncImpl.includes('mdConsistencyClockDiffers(remote.clock,local.clock,Date.now())'),'passive Bridge follow does not compare clocks');
const clocksDiffer=new Function(clockImpl+';return mdConsistencyClockDiffers')();
const clockAt=(baseSeconds,running,stamp)=>({baseSeconds,running,startedAt:new Date(stamp).toISOString()});
assert(!clocksDiffer(clockAt(60,true,1000),clockAt(64.2,true,5000),5000),'equivalent running clock or subsecond delay treated as drift');
assert(clocksDiffer(clockAt(60,true,1000),clockAt(62,false,5000),5000),'running versus paused clock mismatch ignored');
assert(clocksDiffer(clockAt(60,true,1000),clockAt(60,true,5000),5000),'running clock drift ignored');
assert(clocksDiffer(clockAt(60,false,1000),clockAt(63,false,5000),5000),'paused clock drift ignored');
assert(!clocksDiffer({period:'2H'},clockAt(63,false,5000),5000),'legacy clock without running metadata caused a repair');
console.log('PASS passive Bridge follow detects same-revision clock drift');

const retryImpl=control.match(/async function mdPostMatchdayWithRetry\(state\)\{[\s\S]*?(?=\r?\nwindow.sagiMatchdayReliabilityDiagnostic)/)?.[0];
assert(retryImpl,'matchday retry implementation missing');
const makeRetryHarness=new Function(`
 let fixture='one',sent=0,persisted=0,recovered=0,releasePost,releaseDelay;
 const mdFixtureKey=()=>fixture,mdPublishMetrics={},mdRecoveryMetrics={};
 const lanPost=()=>{sent++;return new Promise((resolve,reject)=>{releasePost={resolve,reject}});};
 const mdDelay=()=>new Promise(resolve=>{releaseDelay=resolve;});
 const mdSaveLastGood=()=>{persisted++};
 const recoverMatchdayFromBridge=async()=>{recovered++;return true};
 ${retryImpl}
 return {send:mdPostMatchdayWithRetry,switchFixture:()=>{fixture='two'},settle:error=>error?releasePost.reject(error):releasePost.resolve(),resume:()=>releaseDelay(),counts:()=>[sent,persisted,recovered]};
`);
const delayedRetry=makeRetryHarness(),queued=delayedRetry.send({fixtureKey:'one',allowFixtureTakeover:true});
delayedRetry.settle(new Error('temporary'));await Promise.resolve();
delayedRetry.switchFixture();delayedRetry.resume();
assert((await queued).skipped&&JSON.stringify(delayedRetry.counts())==='[1,0,0]','retry transmitted a previously selected fixture');
for(const responseError of [null,new Error('LAN 409')]){
 const h=makeRetryHarness(),send=h.send({fixtureKey:'one'});
 h.switchFixture();h.settle(responseError);
 assert((await send).skipped&&JSON.stringify(h.counts())==='[1,0,0]','obsolete response changed recovery state for the current fixture');
}
console.log('PASS stale fixture writes stop retrying and cannot mutate current recovery state');

const recoveryImpl=control.match(/async function recoverMatchdayFromBridge\(showNote=false,opts=\{\}\)\{[\s\S]*?(?=\r?\nfunction mdResetForProject)/)?.[0];
assert(recoveryImpl,'Bridge conflict recovery implementation missing');
const recoveryHarness=new Function(`
 let fixture='one',complete,examined=0;
 const lanJson=()=>new Promise(resolve=>{complete=resolve});
 const mdFixtureKey=()=>fixture,mdBridgeMatchesCurrent=()=>{examined++;return false};
 ${recoveryImpl}
 return {recover:recoverMatchdayFromBridge,switchFixture:()=>{fixture='two'},deliver:()=>complete({commandId:'from-one'}),examined:()=>examined};
`)();
const obsoleteRecovery=recoveryHarness.recover(false,{allowIdentityTakeover:true,expectedFixture:'one'});
recoveryHarness.switchFixture();recoveryHarness.deliver();
assert(await obsoleteRecovery===false&&recoveryHarness.examined()===0,'late conflict recovery was applied after changing fixtures');
console.log('PASS late conflict recovery respects the selected fixture');
