import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn, spawnSync } from 'node:child_process';

const root = new URL('./', import.meta.url);
const read = name => fs.readFileSync(new URL(name, root), 'utf8');
const html = read('index.html');
const club = read('club.html');
const live = read('live.html');
const admin = read('admin.html');
const manifestText = read('manifest.webmanifest');
const sw = read('sw.js');
const serverPath = fileURLToPath(new URL('china-sync/server.mjs', root));

const failures = [];
function check(ok, msg){ if(!ok) failures.push(msg); }
function checkInlineScripts(source, label){
  const scripts=[...source.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m=>m[1]);
  check(scripts.length>=1,label+' should contain an inline script');
  scripts.forEach((code,i)=>{try{new Function(code)}catch(e){failures.push(label+' script '+(i+1)+' syntax error: '+e.message)}});
  return scripts;
}

const scorerScripts=checkInlineScripts(html,'index.html');
checkInlineScripts(club,'club.html');
checkInlineScripts(live,'live.html');
checkInlineScripts(admin,'admin.html');

try{JSON.parse(manifestText)}catch(e){failures.push('manifest.webmanifest JSON error: '+e.message)}
try{new Function(sw)}catch(e){failures.push('sw.js syntax error: '+e.message)}

const serverCheck=spawnSync(process.execPath,['--check',serverPath],{encoding:'utf8'});
check(serverCheck.status===0,'China sync server syntax error: '+(serverCheck.stderr||serverCheck.stdout||'unknown'));

const ids=[...html.matchAll(/\bid="([^"]+)"/g)].map(m=>m[1]);
const dup=[...new Set(ids.filter((x,i)=>ids.indexOf(x)!==i))];
check(dup.length===0,'Duplicate ids: '+dup.join(', '));
const refs=[...scorerScripts.join('\n').matchAll(/\$\('#([^']+)'\)/g)].map(m=>m[1]);
const missing=[...new Set(refs.filter(x=>!ids.includes(x)))];
check(missing.length===0,'Referenced ids missing from scorer HTML: '+missing.join(', '));

const required=['camera','cameraBtn','swapBtn','players','eightPanel','chasePanel','undoBtn','newRackBtn','resetBtn','clubName','tableNo','raceTo','settlement','log','extraOverlay','splash','syncUrl','clubId','syncToken','syncTestBtn','liveScreenLink'];
for(const id of required)check(ids.includes(id),'Required scorer UI id missing: '+id);

for(const token of ['中式八球','4球追分','6球追分','9球追分','普胜','小金','大金','黄金9','localStorage','getUserMedia','serviceWorker']){
  check(html.includes(token),'Core capability marker missing: '+token);
}
check(html.includes("state.players.length>=4"),'4-player limit guard missing');
check(html.includes("state.history.length>40"),'Undo history bound missing');
check(html.includes("state.settlement==='transfer'"),'Transfer settlement logic missing');
check(html.includes("state.mode==='8ball'"),'8-ball mode logic missing');
check(html.includes("sagi_pool_live_v20_"),'V2 per-table storage key missing');
check(html.includes('授权无效或已到期'),'License error UI missing from scorer');
check(club.includes('/api/clubs/'),'Club cloud endpoint missing');
check(live.includes('/api/rooms/'),'Live screen cloud endpoint missing');
check(html.includes('webDeviceId()'),'Scorer stable web device identity missing');
check(html.includes("deviceLabel:'Web记分端"),'Scorer device label missing');
check(live.includes('sagi_pool_web_live_device_id_v1'),'Live-screen stable web device identity missing');
check(live.includes("deviceLabel:'Web直播端"),'Live-screen device label missing');
check(admin.includes('/api/admin/licenses'),'Seller license endpoint missing');
check(admin.includes('/api/admin/provisions'),'Seller installation-code endpoint missing');
check(admin.includes('/devices'),'Seller device-management endpoint missing');
check(sw.includes('./club.html')&&sw.includes('./live.html')&&sw.includes('./admin.html'),'Offline cache missing product pages');

async function waitHealth(base){
  for(let i=0;i<50;i++){
    try{const r=await fetch(base+'/health');if(r.ok)return true}catch{}
    await new Promise(r=>setTimeout(r,100));
  }
  return false;
}

async function e2eCommercial(){
  const port=18787;
  const base='http://127.0.0.1:'+port;
  const tmp=path.join(os.tmpdir(),'sagi-pool-selftest-'+process.pid+'.json');
  try{fs.rmSync(tmp,{force:true})}catch{}
  const child=spawn(process.execPath,[serverPath],{
    env:{...process.env,PORT:String(port),HOST:'127.0.0.1',SAGI_REQUIRE_LICENSE:'1',SAGI_ADMIN_TOKEN:'admin-secret',SAGI_DATA_FILE:tmp},
    stdio:['ignore','pipe','pipe']
  });
  let stderr='';child.stderr.on('data',d=>stderr+=d.toString());
  try{
    check(await waitHealth(base),'China sync /health did not start: '+stderr);

    const pre=await fetch(base+'/api/clubs/TEST-CLUB',{headers:{'X-SAGI-Token':'club-secret'}});
    check(pre.status===401,'Unlicensed club should be rejected');

    const badAdmin=await fetch(base+'/api/admin/licenses',{method:'POST',headers:{'Content-Type':'application/json','X-SAGI-Admin':'wrong'},body:'{}'});
    check(badAdmin.status===401,'Wrong admin token should be rejected');

    const expires=Date.now()+86400000;
    const issue=await fetch(base+'/api/admin/licenses',{
      method:'POST',
      headers:{'Content-Type':'application/json','X-SAGI-Admin':'admin-secret'},
      body:JSON.stringify({clubId:'TEST-CLUB',clubName:'测试球房',plan:'CLUB PRO',maxTables:2,expiresAt:expires,token:'club-secret'})
    });
    const issueData=await issue.json();
    check(issue.ok&&issueData.license?.active===true,'License issuance failed');
    check(issueData.license?.maxTables===2,'License maxTables incorrect');

    const lic=await fetch(base+'/api/license/TEST-CLUB',{headers:{'X-SAGI-Token':'club-secret'}});
    const licData=await lic.json();
    check(lic.ok&&licData.license?.plan==='CLUB PRO','License verification failed');

    const wrong=await fetch(base+'/api/rooms/TEST-CLUB/01%E6%A1%8C',{headers:{'X-SAGI-Token':'wrong-token'}});
    check(wrong.status===401,'Wrong club token should be rejected');

    const state={mode:'chase6',club:'测试球房',table:'01桌',players:[{name:'A',score:3,wins:0},{name:'B',score:1,wins:0}],log:[{type:'大金'}],updatedAt:Date.now()};
    const post=await fetch(base+'/api/rooms/TEST-CLUB/01%E6%A1%8C',{
      method:'POST',
      headers:{'Content-Type':'application/json','X-SAGI-Token':'club-secret'},
      body:JSON.stringify({state,updatedAt:state.updatedAt,deviceId:'selftest'})
    });
    check(post.ok,'Licensed room POST failed: '+post.status);

    const one=await fetch(base+'/api/rooms/TEST-CLUB/01%E6%A1%8C',{headers:{'X-SAGI-Token':'club-secret'}});
    const oneData=await one.json();
    check(one.ok&&oneData.room?.state?.players?.[0]?.score===3,'Room readback failed');

    const all=await fetch(base+'/api/clubs/TEST-CLUB',{headers:{'X-SAGI-Token':'club-secret'}});
    const allData=await all.json();
    check(all.ok&&allData.rooms?.length===1,'Club list failed');
    check(allData.rooms?.[0]?.state?.mode==='chase6','Club list missing full room state');

    const provision=await fetch(base+'/api/admin/provisions',{
      method:'POST',
      headers:{'Content-Type':'application/json','X-SAGI-Admin':'admin-secret'},
      body:JSON.stringify({clubId:'TEST-CLUB',table:'02桌'})
    });
    const provisionData=await provision.json();
    check(provision.ok&&/^[2-9A-HJ-NP-Z]{8}$/.test(provisionData.provision?.code||''),'Provision code creation failed');

    const installCode=provisionData.provision.code;
    const claim=await fetch(base+'/api/provision/claim',{
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body:JSON.stringify({code:installCode})
    });
    const claimData=await claim.json();
    check(claim.ok&&claimData.config?.clubId==='TEST-CLUB','Provision claim failed');
    check(claimData.config?.table==='02桌','Provision table binding failed');
    check((claimData.config?.token||'').length>=32,'Provision device token missing');
    check((claimData.config?.deviceId||'').length>=6,'Provision device id missing');

    const reuse=await fetch(base+'/api/provision/claim',{
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body:JSON.stringify({code:installCode})
    });
    check(reuse.status===404||reuse.status===410,'Provision code must be one-time');

    const deviceToken=claimData.config.token;
    const deviceRead=await fetch(base+'/api/rooms/TEST-CLUB/02%E6%A1%8C',{
      headers:{'X-SAGI-Token':deviceToken}
    });
    check(deviceRead.ok,'Provisioned device token authorization failed');

    const liveStart=await fetch(base+'/api/devices/TEST-CLUB/'+encodeURIComponent(claimData.config.deviceId)+'/live',{
      method:'POST',
      headers:{'Content-Type':'application/json','X-SAGI-Token':deviceToken},
      body:JSON.stringify({action:'start',bitrate:1600,fps:24,width:1280,height:720})
    });
    check(liveStart.ok,'Live session start telemetry failed');

    const liveHeartbeat=await fetch(base+'/api/devices/TEST-CLUB/'+encodeURIComponent(claimData.config.deviceId)+'/live',{
      method:'POST',
      headers:{'Content-Type':'application/json','X-SAGI-Token':deviceToken},
      body:JSON.stringify({action:'heartbeat',bitrate:1450,fps:24,width:1280,height:720})
    });
    check(liveHeartbeat.ok,'Live session heartbeat failed');

    const liveDevices=await fetch(base+'/api/admin/licenses/TEST-CLUB/devices',{headers:{'X-SAGI-Admin':'admin-secret'}});
    const liveDevicesData=await liveDevices.json();
    check(liveDevices.ok&&liveDevicesData.devices?.[0]?.live?.active===true,'Admin live-now device state failed');
    check(Number(liveDevicesData.devices?.[0]?.live?.bitrate||0)===1450,'Live bitrate telemetry failed');

    const liveStop=await fetch(base+'/api/devices/TEST-CLUB/'+encodeURIComponent(claimData.config.deviceId)+'/live',{
      method:'POST',
      headers:{'Content-Type':'application/json','X-SAGI-Token':deviceToken},
      body:JSON.stringify({action:'stop'})
    });
    check(liveStop.ok,'Live session stop telemetry failed');

    const sessionsBeforeRevoke=await fetch(
      base+'/api/admin/licenses/TEST-CLUB/devices/'+encodeURIComponent(claimData.config.deviceId)+'/sessions',
      {headers:{'X-SAGI-Admin':'admin-secret'}}
    );
    const sessionsBeforeRevokeData=await sessionsBeforeRevoke.json();
    check(sessionsBeforeRevoke.ok&&sessionsBeforeRevokeData.sessions?.length===1,'Live session history creation failed');
    check(Number(sessionsBeforeRevokeData.sessions?.[0]?.maxBitrate||0)===1600,'Live max bitrate history failed');

    const over=await fetch(base+'/api/rooms/TEST-CLUB/03%E6%A1%8C',{headers:{'X-SAGI-Token':deviceToken}});
    const overData=await over.json();
    check(over.status===403&&overData.error==='table_limit_exceeded','Table limit enforcement failed for device token');

    const list=await fetch(base+'/api/admin/licenses',{headers:{'X-SAGI-Admin':'admin-secret'}});
    const listData=await list.json();
    check(list.ok&&listData.licenses?.some(x=>x.clubId==='TEST-CLUB'),'Admin license listing failed');
    const listedLicense=listData.licenses.find(x=>x.clubId==='TEST-CLUB');
    check(Number(listedLicense?.deviceCount||0)===1,'License device count failed');

    const devices=await fetch(base+'/api/admin/licenses/TEST-CLUB/devices',{headers:{'X-SAGI-Admin':'admin-secret'}});
    const devicesData=await devices.json();
    check(devices.ok&&devicesData.devices?.length===1,'Admin device listing failed');
    const deviceId=devicesData.devices?.[0]?.id;
    check(Boolean(deviceId),'Admin device id missing');

    const liveRestart=await fetch(base+'/api/devices/TEST-CLUB/'+encodeURIComponent(deviceId)+'/live',{
      method:'POST',
      headers:{'Content-Type':'application/json','X-SAGI-Token':deviceToken},
      body:JSON.stringify({action:'start',bitrate:1200,fps:23,width:1280,height:720})
    });
    check(liveRestart.ok,'Live restart before remote revoke failed');

    const revokeDevice=await fetch(base+'/api/admin/licenses/TEST-CLUB/devices/'+encodeURIComponent(deviceId)+'/revoke',{
      method:'POST',
      headers:{'X-SAGI-Admin':'admin-secret'}
    });
    check(revokeDevice.ok,'Per-device revoke failed');

    const sessionsAfterRevoke=await fetch(
      base+'/api/admin/licenses/TEST-CLUB/devices/'+encodeURIComponent(deviceId)+'/sessions',
      {headers:{'X-SAGI-Admin':'admin-secret'}}
    );
    const sessionsAfterRevokeData=await sessionsAfterRevoke.json();
    check(sessionsAfterRevoke.ok&&sessionsAfterRevokeData.sessions?.length===2,'Remote revoke should close active live session');
    check(sessionsAfterRevokeData.sessions?.[0]?.reason==='remote_revoke','Remote revoke session reason missing');

    const afterDeviceRevoke=await fetch(base+'/api/rooms/TEST-CLUB/02%E6%A1%8C',{
      headers:{'X-SAGI-Token':deviceToken}
    });
    check(afterDeviceRevoke.status===401,'Revoked device token should be rejected');

    const mainStillWorks=await fetch(base+'/api/rooms/TEST-CLUB/01%E6%A1%8C',{
      headers:{'X-SAGI-Token':'club-secret'}
    });
    check(mainStillWorks.ok,'Device revoke must not disable club main token');

    const revoke=await fetch(base+'/api/admin/licenses/TEST-CLUB/revoke',{method:'POST',headers:{'X-SAGI-Admin':'admin-secret'}});
    check(revoke.ok,'License revoke failed');

    const after=await fetch(base+'/api/clubs/TEST-CLUB',{headers:{'X-SAGI-Token':'club-secret'}});
    check(after.status===401,'Revoked license should be rejected');
  }catch(e){
    failures.push('Commercial China E2E error: '+e.message);
  }finally{
    child.kill('SIGTERM');
    try{fs.rmSync(tmp,{force:true})}catch{}
  }
}

await e2eCommercial();

if(failures.length){
  console.error('\nSAGI POOL LIVE SELF-CHECK: FAILED');
  failures.forEach((x,i)=>console.error((i+1)+'. '+x));
  process.exit(1);
}
console.log('SAGI POOL LIVE CHINA V2.4 SELF-CHECK: PASSED');
console.log('✓ Scorer / club / live / seller JavaScript');
console.log('✓ PWA cache and core billiards scoring');
console.log('✓ China sync real read/write flow');
console.log('✓ Per-club license issuance');
console.log('✓ Wrong-token rejection');
console.log('✓ Purchased table-count enforcement');
console.log('✓ One-time install code → per-device token');
console.log('✓ Install code one-use enforcement');
console.log('✓ Device inventory and per-device remote revoke');
console.log('✓ Live start / heartbeat / stop telemetry');
console.log('✓ Live session history and remote-revoke closure');
console.log('✓ Admin license listing and revoke');
