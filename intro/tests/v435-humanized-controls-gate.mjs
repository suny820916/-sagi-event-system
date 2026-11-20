import fs from 'node:fs';
function assert(ok,msg){if(!ok)throw new Error(msg)}
const control=fs.readFileSync(new URL('../v45-lan.html',import.meta.url),'utf8');
const output=fs.readFileSync(new URL('../vmix-v45-lan.html',import.meta.url),'utf8');
const pkg=fs.readFileSync(new URL('../SAGI_VMIX_LAN_V435_HUMANIZED_CONTROLS_RC.bat',import.meta.url),'utf8');

for(const token of [
 'SAGI435_HUMANIZED_CONTROLS_RC1','SAGI_MATCH_PROJECTS_V2','window.sagiProjectSyncDiagnostic',
 "sourceVersion='V4.33'",'mdLocalMutationDepth',
 'id="mmCommandDeck"','id="mmTakePreview"','PROGRAM / PREVIEW · 机位优先',
 'function mmCameraPreviewFirst()','async function mmSelectCamera(slot)','async function mmTakePendingCamera()',
 'window.sagiHumanizedCameraDiagnostic'
]) assert(control.includes(token),'V4.35 humanized control missing/inheritance lost: '+token);

for(const id of ['mmCam1','mmCam2','mmDrone','mmTakePreview','mmGoalMacro','mmReplay','mmReturnLive','mmSafeCam']){
 const count=(control.match(new RegExp('id="'+id+'"','g'))||[]).length;
 assert(count===1,'V4.35 duplicate/missing control '+id+': '+count)
}
assert(control.includes("matchMedia('(max-width:700px)')"),'V4.35 mobile preview-first breakpoint missing');
assert(control.includes("vdPreview(slot)"),'V4.35 mobile camera no longer uses PREVIEW');
assert(control.includes("const ok=await vdTake(slot)"),'V4.35 GO LIVE/direct desktop take missing');
assert(output.includes('SAGI435_HUMANIZED_CONTROLS_RC1'),'V4.35 output reload fingerprint missing');
assert(output.includes('V4.34 SAGI SIGNATURE · REPLAY BRAND TRANSITION'),'V4.35 lost V4.34 replay brand visuals');

const lines=pkg.split(/\r?\n/),c=lines.indexOf('###SAGI_CONTROL###'),o=lines.indexOf('###SAGI_OUTPUT###');
assert(c>0&&o>c,'V4.35 package markers invalid');
const pkgControl=lines.slice(c+1,o).join('\n').trim().replace(/\r/g,'');
const pkgOutput=lines.slice(o+1).join('\n').trim().replace(/\r/g,'');
assert(pkgControl===control.trim().replace(/\r/g,''),'V4.35 packaged control drift');
assert(pkgOutput===output.trim().replace(/\r/g,''),'V4.35 packaged output drift');
for(const token of ['SAGI435_HUMANIZED_CONTROLS_RC1','SAGI_MATCH_PROJECTS_V2','activeProjectId','mdLocalMutationDepth','mmTakePreview']) assert(pkg.includes(token),'V4.35 package lost certified foundation: '+token);
console.log('SAGI V4.35 HUMANIZED CONTROLS + PACKAGE PARITY GATE PASS');
