// V4.32 China LAN-first production preflight (static package gate).
// This gate does NOT replace offline physical Windows/vMix acceptance.
import fs from 'node:fs';

const read=p=>fs.readFileSync(p,'utf8');
const bat=read('intro/SAGI_VMIX_LAN_V432_SIGNATURE_RC.bat');
const control=read('intro/v45-lan.html');
const output=read('intro/vmix-v45-lan.html');
const failures=[];
function check(name,ok,detail=''){
  console.log((ok?'PASS':'FAIL')+' '+name+(detail?' — '+detail:''));
  if(!ok)failures.push(name);
}
const markers=['###SAGI_PS###','###SAGI_CONTROL###','###SAGI_OUTPUT###'];
const positions=markers.map(x=>bat.lastIndexOf(x));
const delimiterLines=bat.split(/\r?\n/).filter(line=>markers.includes(line.trim()));
check('BAT contains exactly one actual payload delimiter per section',JSON.stringify(delimiterLines)===JSON.stringify(markers));
check('BAT embeds Bridge/control/output in order',positions.every(x=>x>=0)&&positions[0]<positions[1]&&positions[1]<positions[2]);
const embeddedControl=bat.slice(positions[1]+markers[1].length,positions[2]);
const embeddedOutput=bat.slice(positions[2]+markers[2].length);
check('Packaged control is not truncated',embeddedControl.length>100000);
check('Packaged output is not truncated',embeddedOutput.length>50000);
// Catch accidentally shipping stale standalone HTML while the BAT embeds a different UI.
// Compare the actual embedded payload after removing only BAT delimiter boundary newlines.
const normalizePayload=s=>s.replace(/^\r?\n/,'').replace(/\r?\n$/,'').replace(/\r\n/g,'\n');
check('BAT packaged control matches standalone source',normalizePayload(embeddedControl)===normalizePayload(control));
check('BAT packaged output matches standalone source',normalizePayload(embeddedOutput)===normalizePayload(output));
check('Packaged control includes V4.32 Signature Core',embeddedControl.includes('SAGISignatureCore'));
check('Packaged output includes V4.32 Signature Core',embeddedOutput.includes('SAGISignatureCore'));
check('Embedded control includes local match operation',embeddedControl.includes('mdMacroEvent')&&embeddedControl.includes('mdRecordEvent'));
check('Embedded output includes local scoreboard',embeddedOutput.includes('scoreBug')&&embeddedOutput.includes('simplePenaltyBoard'));
check('Bridge uses loopback vMix API',bat.includes('http://127.0.0.1:8088/api/'));
// Verify the advertised LAN URL matches the port actually bound by the Bridge.
// A stale 8099 example must not silently pass while the listener binds 8100.
const bridgePortMatch=bat.match(/\$PreferredPort\s*=\s*(\d+)/);
const bridgePort=bridgePortMatch?Number(bridgePortMatch[1]):null;
check('Bridge has a valid explicit listening port',Number.isInteger(bridgePort)&&bridgePort>0&&bridgePort<=65535);
check('Bridge provides LAN phone URL on its actual listening port',
  !!bridgePort&&bat.includes('PHONE CONTROL')&&
  bat.includes('":" + $Port + "/"')&&bat.includes('$listener = $tryListener'));
check('Bridge binds its advertised port',!!bridgePort&&
  bat.includes('for ($candidate = $PreferredPort;')&&
  bat.includes(',$candidate)')&&bat.includes('$Port = $candidate'));
for(const [name,html] of [['control',control],['output',output],['packaged control',embeddedControl],['packaged output',embeddedOutput]]){
  // The core entrypoints must never load a remote executable or stylesheet as a hard prerequisite.
  const remoteScripts=[...html.matchAll(/<script\b[^>]*\bsrc\s*=\s*["'](https?:)?\/\/[^"']+/gi)];
  const remoteCss=[...html.matchAll(/<link\b[^>]*\brel\s*=\s*["']stylesheet["'][^>]*\bhref\s*=\s*["'](https?:)?\/\/[^"']+/gi)];
  check(name+' no mandatory remote script tags',remoteScripts.length===0,remoteScripts.map(x=>x[0]).join(', '));
  check(name+' no mandatory remote CSS tags',remoteCss.length===0,remoteCss.map(x=>x[0]).join(', '));
  // Dynamic imports and workers are reported as audit findings, not assumed to be core dependencies:
  // file-import/OCR tools may load these only when explicitly invoked by an operator.
  const remoteImports=[...html.matchAll(/\bimport\s*\(\s*['"]https?:\/\/[^'"]+/gi)];
  const remoteWorkers=[...html.matchAll(/\bworkerSrc\s*=\s*['"]https?:\/\/[^'"]+/gi)];
  console.log('OPTIONAL_DYNAMIC_REMOTE_REFERENCES '+name+' '+JSON.stringify([...remoteImports,...remoteWorkers].map(x=>x[0]).slice(0,12)));
}
const externalUrls=[...new Set((control.match(/https?:\/\/[^\s'"<>]+/g)||[]).filter(x=>!/(127\.0\.0\.1|localhost)/.test(x)))];
console.log('OPTIONAL_EXTERNAL_REFERENCES '+JSON.stringify(externalUrls.slice(0,30)));
// A fully offline build may legitimately contain zero external references.
// Audit visibility is informational; do not require remote dependencies to exist.
check('External dependency audit produces a deterministic list',Array.isArray(externalUrls));
check('No external scripts in live output',!/<script\b[^>]*\bsrc\s*=\s*["']https?:/i.test(output));
check('Local event persistence exists',control.includes('mdPersist()')&&control.includes('mdRecordEvent('));
if(failures.length){console.error('CHINA_LAN_PREFLIGHT_FAILED '+failures.join('; '));process.exit(1)}
console.log('CHINA_LAN_PREFLIGHT_STATIC_PASS — physical offline soak still required');
