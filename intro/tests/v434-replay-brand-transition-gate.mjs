import fs from 'node:fs';
function assert(ok,msg){if(!ok)throw new Error(msg)}
const control=fs.readFileSync(new URL('../v45-lan.html',import.meta.url),'utf8');
const output=fs.readFileSync(new URL('../vmix-v45-lan.html',import.meta.url),'utf8');
const pkg=fs.readFileSync(new URL('../SAGI_VMIX_LAN_V434_REPLAY_BRAND_RC.bat',import.meta.url),'utf8');

for(const token of [
 'SAGI434_REPLAY_BRAND_RC1','SAGI_MATCH_PROJECTS_V2','window.sagiProjectSyncDiagnostic',
 "function mdPenaltyCompatView()","sourceVersion='V4.33'","window.sagiPenaltySingleSourceDiagnostic",
 'mdLocalMutationDepth',"mdPendingPublishes>0||mdLocalMutationDepth>0"
]) assert(control.includes(token),'V4.34 control lost inherited foundation: '+token);

for(const token of [
 'SAGI434_REPLAY_BRAND_RC1',
 'V4.34 SAGI SIGNATURE · REPLAY BRAND TRANSITION',
 'data-brand-source="sagi-safe"',
 'function setReplayBrandSource(st,logo,fallback,source)',
 "setReplayBrandSource(st,logo,fallback,'sagi-safe')",
 "setReplayBrandSource(st,logo,fallback,'event')",
 'id="rsCompetition"',
 'LIVE PRODUCTION',
 'rsLogoFallback on'
]) assert(output.includes(token),'V4.34 replay brand transition missing: '+token);

assert(!output.includes("const src=(g&&g.eventLogo)||(g&&g.logo)||'data:image/svg+xml"),'legacy giant replay fallback still controls V4.34');
assert(output.includes("logo.onerror=()=>{logo.removeAttribute('src');setReplayBrandSource(st,logo,fallback,'sagi-safe')}"),'replay logo error does not fail safe');

const lines=pkg.split(/\r?\n/),c=lines.indexOf('###SAGI_CONTROL###'),o=lines.indexOf('###SAGI_OUTPUT###');
assert(c>0&&o>c,'V4.34 package markers invalid');
const pkgControl=lines.slice(c+1,o).join('\n').trim().replace(/\r/g,'');
const pkgOutput=lines.slice(o+1).join('\n').trim().replace(/\r/g,'');
const currentBuild=Number((control.match(/SAGI4(\d{2})_[A-Z0-9_]+/)||[])[1]||0);
assert(currentBuild>=34,'current source regressed below V4.34');
if(currentBuild===34){
 assert(pkgControl===control.trim().replace(/\r/g,''),'V4.34 packaged control drift');
 assert(pkgOutput===output.trim().replace(/\r/g,''),'V4.34 packaged output drift');
}
for(const token of ['SAGI434_REPLAY_BRAND_RC1','SAGI_MATCH_PROJECTS_V2','activeProjectId','mdLocalMutationDepth']) assert(pkg.includes(token),'historical V4.34 package lost inherited SSOT/race protection: '+token);
for(const token of ['V4.34 SAGI SIGNATURE · REPLAY BRAND TRANSITION','data-brand-source="sagi-safe"','function setReplayBrandSource(st,logo,fallback,source)','id="rsCompetition"']) assert(pkgOutput.includes(token),'historical V4.34 replay output lost certified brand transition: '+token);
console.log('SAGI V4.34 FORWARD-COMPAT + HISTORICAL REPLAY PACKAGE GATE PASS');
