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
