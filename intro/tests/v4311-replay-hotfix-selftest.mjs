// V4.31.1 replay hotfix PR synchronization gate
import fs from 'node:fs';
function assert(ok,msg){if(!ok)throw new Error(msg)}
const control=fs.readFileSync(new URL('../v45-lan.html',import.meta.url),'utf8');
const bat=fs.readFileSync(new URL('../SAGI_VMIX_LAN_V4311_REPLAY_HOTFIX.bat',import.meta.url),'utf8');
for(const token of ['V4.31.1','irGenerate','mmGenerateReplay','instantReplayStartRecording','instantReplayGenerate','ReplayStartRecording','ReplayMarkInOutLive','ReplayPlayLastEventToOutput','ReplayStopEvents']){
 assert(control.includes(token)||bat.includes(token),'missing replay hotfix token: '+token);
}
assert(control.includes("[5,8,12].includes(Number(seconds))"),'duration whitelist missing');
assert(control.includes("seconds*1000+900"),'automatic return timer missing');
assert(control.includes("if(instantReplayBusy)"),'repeat-click guard missing');
assert(control.includes("clearTimeout(instantReplayTimer)"),'timer cleanup missing');
const lines=bat.split(/\r?\n/);
const c=lines.indexOf('###SAGI_CONTROL###'),o=lines.indexOf('###SAGI_OUTPUT###');
assert(c>0&&o>c,'BAT payload markers invalid');
const embedded=lines.slice(c+1,o).join('\n').trim().replace(/\r/g,'');
assert(embedded===control.trim().replace(/\r/g,''),'BAT embedded control drift');
assert(lines.slice(0,c).join('\n').includes('"ReplayMarkInOutLive"'),'bridge allowlist missing replay generation');
assert(lines.slice(o+1).join('\n').includes('V4.31.0'),'certified V4.31.0 graphics baseline missing');
console.log('SAGI V4.31.1 INSTANT REPLAY HOTFIX GATE PASS');

// output build route isolation: vMix output must not compare itself against the control UI version.
const output=fs.readFileSync(new URL('../vmix-v45-lan.html',import.meta.url),'utf8');
assert(output.includes("fetch('/vmix?graphicsBuild='"),'output build checker must read /vmix, not control root');
assert(!output.includes("fetch('/?graphicsBuild='"),'control-root version check would cause reload flashing when UI hotfix is newer');
console.log('output build route isolation PASS');

// opening white-flash protection
const control2=fs.readFileSync(new URL('../v45-lan.html',import.meta.url),'utf8');
const output2=fs.readFileSync(new URL('../vmix-v45-lan.html',import.meta.url),'utf8');
assert(!control2.includes("transition:'FLASH'"),'default opening show must not use FLASH');
assert(control2.includes("s.transition==='FLASH'?'FADE'"),'saved FLASH timelines must normalize to FADE');
assert(!control2.includes("['CUT','FADE','SLIDE','ZOOM','FLASH']"),'operator must not be offered white FLASH transition');
assert(output2.includes("if(type==='FLASH'){type='FADE'}"),'legacy output FLASH must degrade to FADE');
assert(!output2.includes("opacity:.82,offset:.28"),'white flash animation must be removed');
console.log('opening white-flash protection PASS');

// opening boot transparency and stale-state cleanup
const control3=fs.readFileSync(new URL('../v45-lan.html',import.meta.url),'utf8');
const output3=fs.readFileSync(new URL('../vmix-v45-lan.html',import.meta.url),'utf8');
assert(output3.includes("background:#07090c;transform-origin:0 0;opacity:0"),'opening stage must be hidden on first paint');
assert(output3.includes("q('stage').style.opacity='1'"),'valid opening state must explicitly reveal stage');
assert(output3.includes("q('stage').style.opacity='0'"),'CLEAR must hide opening stage');
assert(control3.includes("完整出场结束自动清屏"),'full intro completion must clear stale opening state');
assert(control3.includes("publishGroup('CLEAR',200,clearMeta)"),'full intro completion CLEAR publish missing');
console.log('opening boot transparency PASS');

// lineup program gate: stale Bridge lineup states must never flash on air
const control4=fs.readFileSync(new URL('../v45-lan.html',import.meta.url),'utf8');
const output4=fs.readFileSync(new URL('../vmix-v45-lan.html',import.meta.url),'utf8');
assert(control4.includes("programGate:'SAGI4311_PROGRAM'"),'control must stamp explicit PROGRAM gate');
assert(control4.includes("onAir:true"),'control must stamp onAir state');
assert(control4.includes("expiresAtMs"),'control must publish lineup expiry');
assert(output4.includes("function introStateAllowed"),'output PROGRAM gate missing');
assert(output4.includes("x.programGate!=='SAGI4311_PROGRAM'"),'legacy/stale lineup state rejection missing');
assert(output4.includes("hideIntroStage('STALE_STATE')"),'poll stale-state hide guard missing');
assert(output4.includes("hideIntroStage('EXPIRED')"),'expired lineup auto-hide missing');
console.log('lineup program gate PASS');

// stale-cache install gate: every distributed BAT must force old cached UI/output out.
const bat5=fs.readFileSync(new URL('../SAGI_VMIX_LAN_V4311_REPLAY_HOTFIX.bat',import.meta.url),'utf8');
const control5=fs.readFileSync(new URL('../v45-lan.html',import.meta.url),'utf8');
const output5=fs.readFileSync(new URL('../vmix-v45-lan.html',import.meta.url),'utf8');
assert(control5.includes('SAGI4311_FLASHFIX_04'),'control build fingerprint missing');
assert(output5.includes('SAGI4311_FLASHFIX_04'),'output build fingerprint missing');
assert(bat5.includes("$t -match 'SAGI4311_FLASHFIX_04'"),'BAT bootstrap must require current build fingerprint');
assert(bat5.includes("FLASHFIX 04 vMix output installed over stale cache"),'stale output replacement message missing');
assert(bat5.includes("Remote vMix output is older than FLASHFIX 04"),'remote downgrade guard missing');
console.log('stale-cache install gate PASS');

// startup vMix BrowserReload: after stale-cache replacement, force the running vMix Browser Input to load it.
const control6=fs.readFileSync(new URL('../v45-lan.html',import.meta.url),'utf8');
const bat6=fs.readFileSync(new URL('../SAGI_VMIX_LAN_V4311_REPLAY_HOTFIX.bat',import.meta.url),'utf8');
assert(control6.includes("sagi_graphics_loaded_SAGI4311_FLASHFIX_04"),'per-build browser reload marker missing');
assert(control6.includes("refreshGraphicsBrowser(false)"),'startup graphics reload call missing');
assert(bat6.includes('"BrowserReload"'),'Bridge BrowserReload allowlist missing');
console.log('startup vMix BrowserReload PASS');

// single-instance port takeover: never leave vMix pointing at an older bridge on 8100.
const bat7=fs.readFileSync(new URL('../SAGI_VMIX_LAN_V4311_REPLAY_HOTFIX.bat',import.meta.url),'utf8');
assert(bat7.includes('[TAKEOVER] Closing previous SAGI Bridge instance'),'old bridge takeover missing');
assert(bat7.includes("Stop-Process -Id $_.ProcessId -Force"),'old bridge termination missing');
assert(bat7.includes('$candidate -le $PreferredPort'),'port must be locked to 8100');
assert(!bat7.includes('$candidate -le 8120'),'silent 8101+ fallback must be disabled');
console.log('single-instance port takeover PASS');

// replay latest-only + SAGI IN/OUT transition flow
const control7=fs.readFileSync(new URL('../v45-lan.html',import.meta.url),'utf8');
assert(control7.includes("async function replayStingerAction"),'shared replay transition action missing');
assert(control7.includes("replayStingerAction('IN'"),'INSTANT REPLAY transition missing');
assert(control7.includes("replayStingerAction('OUT'"),'BACK TO LIVE transition missing');
assert(control7.includes("ReplayPlayLastEventToOutput"),'latest-event replay command missing');
assert(control7.includes("if(slot==='replay')return instantReplayPlayLatest()"),'Replay slot must play latest event only');
assert(control7.includes("q('mmReplay').onclick=instantReplayPlayLatest"),'match replay button latest-only binding missing');
assert(control7.includes("else if(e.key==='4')instantReplayPlayLatest()"),'keyboard 4 latest-only binding missing');
assert(!control7.includes("q('mmReplay').onclick=()=>vdTake('replay')"),'old full Replay-input switch binding still present');
assert(control7.includes("ReplayStopEvents"),'old replay playback stop guard missing');
console.log('replay latest-only transition flow PASS');
