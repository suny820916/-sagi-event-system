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
