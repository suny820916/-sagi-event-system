import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

const PORT = Number(process.env.PORT || 8787);
const HOST = process.env.HOST || '0.0.0.0';
const LEGACY_TOKEN = process.env.SAGI_SYNC_TOKEN || '';
const ADMIN_TOKEN = process.env.SAGI_ADMIN_TOKEN || '';
const REQUIRE_LICENSE = process.env.SAGI_REQUIRE_LICENSE === '1';
const ALLOW_ORIGIN = process.env.SAGI_ALLOW_ORIGIN || '*';
const DATA_FILE = process.env.SAGI_DATA_FILE || path.join(path.dirname(fileURLToPath(import.meta.url)), 'data.json');

let store = { rooms: {}, licenses: {} };
try {
  if (fs.existsSync(DATA_FILE)) store = JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
} catch (e) {
  console.error('Failed to load data file:', e.message);
}
if (!store.rooms) store.rooms = {};
if (!store.licenses) store.licenses = {};

const clients = new Map();
let persistTimer = null;

function cors(res) {
  res.setHeader('Access-Control-Allow-Origin', ALLOW_ORIGIN);
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, X-SAGI-Token, X-SAGI-Admin');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  res.setHeader('Access-Control-Max-Age', '86400');
}
function json(res, code, body) {
  cors(res);
  res.writeHead(code, {'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'});
  res.end(JSON.stringify(body));
}
function safePart(v) {
  return decodeURIComponent(v || '').replace(/[^\p{L}\p{N}_\-.]/gu, '').slice(0,64);
}
function hashToken(v) {
  return crypto.createHash('sha256').update(String(v || '')).digest('hex');
}
function requestToken(req, url) {
  return String(req.headers['x-sagi-token'] || url.searchParams.get('token') || '');
}
function adminAuthorized(req) {
  return Boolean(ADMIN_TOKEN) && String(req.headers['x-sagi-admin'] || '') === ADMIN_TOKEN;
}
function publicLicense(lic) {
  if (!lic) return null;
  return {
    clubId: lic.clubId,
    clubName: lic.clubName || '',
    plan: lic.plan || 'CLUB',
    maxTables: Number(lic.maxTables || 1),
    expiresAt: Number(lic.expiresAt || 0),
    active: lic.revoked !== true && (!lic.expiresAt || Date.now() < Number(lic.expiresAt)),
    createdAt: Number(lic.createdAt || 0),
    updatedAt: Number(lic.updatedAt || 0)
  };
}
function licenseAuthorized(club, token) {
  const lic = store.licenses[club];
  if (!lic) return false;
  if (lic.revoked === true) return false;
  if (lic.expiresAt && Date.now() >= Number(lic.expiresAt)) return false;
  return Boolean(token) && hashToken(token) === lic.tokenHash;
}
function authorizedForClub(req, url, club) {
  const token = requestToken(req, url);
  if (licenseAuthorized(club, token)) return true;
  if (LEGACY_TOKEN && token === LEGACY_TOKEN) return true;
  if (!REQUIRE_LICENSE && !LEGACY_TOKEN && !store.licenses[club]) return true;
  return false;
}
function tableAllowed(club, table) {
  const lic = store.licenses[club];
  if (!lic) return true;
  const max = Math.max(1, Number(lic.maxTables || 1));
  const n = Number((String(table).match(/\d+/) || [0])[0]);
  if (n > 0) return n <= max;
  const existing = Object.values(store.rooms).filter(r=>r.clubId===club).map(r=>r.table);
  return existing.includes(table) || new Set(existing).size < max;
}
function keyOf(club, table) { return club + '::' + table; }
function schedulePersist() {
  clearTimeout(persistTimer);
  persistTimer = setTimeout(() => {
    try {
      const tmp = DATA_FILE + '.tmp';
      fs.writeFileSync(tmp, JSON.stringify(store, null, 2));
      fs.renameSync(tmp, DATA_FILE);
    } catch (e) {
      console.error('Persist failed:', e.message);
    }
  }, 150);
}
function notify(key, payload) {
  const set = clients.get(key);
  if (!set) return;
  const frame = 'event: state\ndata: ' + JSON.stringify(payload) + '\n\n';
  for (const res of set) {
    try { res.write(frame); } catch {}
  }
}
function readBody(req, limit=1024*1024) {
  return new Promise((resolve,reject)=>{
    let total=0, chunks=[];
    req.on('data',c=>{
      total += c.length;
      if(total > limit){ reject(new Error('payload_too_large')); req.destroy(); return; }
      chunks.push(c);
    });
    req.on('end',()=>resolve(Buffer.concat(chunks).toString('utf8')));
    req.on('error',reject);
  });
}
function roomSummary(room) {
  const s=room?.state || {};
  const players=Array.isArray(s.players)?s.players:[];
  return {
    clubId: room?.clubId || '',
    table: room?.table || '',
    mode: s.mode || '',
    players: players.slice(0,4).map(p=>({name:p.name||'',score:Number(p.score||0),wins:Number(p.wins||0)})),
    updatedAt: Number(room?.updatedAt||0),
    logCount: Array.isArray(s.log)?s.log.length:0,
    state: s
  };
}

const server=http.createServer(async (req,res)=>{
  cors(res);
  if(req.method==='OPTIONS'){res.writeHead(204);res.end();return;}
  const url=new URL(req.url,'http://localhost');

  if(url.pathname==='/health'){
    json(res,200,{ok:true,service:'SAGI CHINA SYNC',version:'2.1.0',licensedMode:REQUIRE_LICENSE,time:Date.now()});
    return;
  }

  if(url.pathname==='/api/admin/licenses' && req.method==='GET'){
    if(!adminAuthorized(req)){json(res,401,{ok:false,error:'admin_unauthorized'});return;}
    const licenses=Object.values(store.licenses).map(publicLicense).sort((a,b)=>(b.updatedAt||0)-(a.updatedAt||0));
    json(res,200,{ok:true,licenses});return;
  }

  if(url.pathname==='/api/admin/licenses' && req.method==='POST'){
    if(!adminAuthorized(req)){json(res,401,{ok:false,error:'admin_unauthorized'});return;}
    try{
      const body=JSON.parse(await readBody(req)||'{}');
      const clubId=safePart(body.clubId);
      const token=String(body.token||'');
      if(!clubId || token.length<8){json(res,400,{ok:false,error:'clubId_and_token_required'});return;}
      const now=Date.now();
      const prev=store.licenses[clubId] || {};
      const lic={
        clubId,
        clubName:String(body.clubName||prev.clubName||'').slice(0,80),
        plan:String(body.plan||prev.plan||'CLUB').slice(0,30),
        maxTables:Math.max(1,Math.min(99,Number(body.maxTables||prev.maxTables||1))),
        expiresAt:Math.max(0,Number(body.expiresAt||prev.expiresAt||0)),
        tokenHash:hashToken(token),
        revoked:false,
        createdAt:Number(prev.createdAt||now),
        updatedAt:now
      };
      store.licenses[clubId]=lic;schedulePersist();
      json(res,200,{ok:true,license:publicLicense(lic)});return;
    }catch(e){json(res,e.message==='payload_too_large'?413:400,{ok:false,error:e.message});return;}
  }

  const revokeMatch=url.pathname.match(/^\/api\/admin\/licenses\/([^/]+)\/revoke$/);
  if(revokeMatch && req.method==='POST'){
    if(!adminAuthorized(req)){json(res,401,{ok:false,error:'admin_unauthorized'});return;}
    const club=safePart(revokeMatch[1]),lic=store.licenses[club];
    if(!lic){json(res,404,{ok:false,error:'license_not_found'});return;}
    lic.revoked=true;lic.updatedAt=Date.now();schedulePersist();
    json(res,200,{ok:true,license:publicLicense(lic)});return;
  }

  const licenseMatch=url.pathname.match(/^\/api\/license\/([^/]+)$/);
  if(licenseMatch && req.method==='GET'){
    const club=safePart(licenseMatch[1]);
    if(!authorizedForClub(req,url,club)){json(res,401,{ok:false,error:'license_invalid_or_expired'});return;}
    json(res,200,{ok:true,license:publicLicense(store.licenses[club])});return;
  }

  const roomMatch=url.pathname.match(/^\/api\/rooms\/([^/]+)\/([^/]+)$/);
  if(roomMatch){
    const club=safePart(roomMatch[1]), table=safePart(roomMatch[2]);
    if(!club||!table){json(res,400,{ok:false,error:'invalid_room'});return;}
    if(!authorizedForClub(req,url,club)){json(res,401,{ok:false,error:'license_invalid_or_expired'});return;}
    if(!tableAllowed(club,table)){json(res,403,{ok:false,error:'table_limit_exceeded',license:publicLicense(store.licenses[club])});return;}
    const key=keyOf(club,table);
    if(req.method==='GET'){
      const room=store.rooms[key];
      json(res,200,{ok:true,room:room||null,license:publicLicense(store.licenses[club])}); return;
    }
    if(req.method==='POST'){
      try{
        const body=JSON.parse(await readBody(req)||'{}');
        if(!body.state || typeof body.state!=='object'){json(res,400,{ok:false,error:'state_required'});return;}
        const updatedAt=Math.max(Date.now(),Number(body.updatedAt||0));
        const prev=store.rooms[key];
        if(prev && Number(body.baseUpdatedAt||0) && Number(body.baseUpdatedAt)<Number(prev.updatedAt||0)){
          json(res,409,{ok:false,error:'stale_state',room:prev}); return;
        }
        const room={clubId:club,table,state:body.state,updatedAt,deviceId:String(body.deviceId||'').slice(0,80)};
        store.rooms[key]=room;schedulePersist();notify(key,room);
        json(res,200,{ok:true,room,license:publicLicense(store.licenses[club])});return;
      }catch(e){json(res,e.message==='payload_too_large'?413:400,{ok:false,error:e.message});return;}
    }
  }

  const eventsMatch=url.pathname.match(/^\/api\/rooms\/([^/]+)\/([^/]+)\/events$/);
  if(eventsMatch && req.method==='GET'){
    const club=safePart(eventsMatch[1]),table=safePart(eventsMatch[2]);
    if(!authorizedForClub(req,url,club)){json(res,401,{ok:false,error:'license_invalid_or_expired'});return;}
    if(!tableAllowed(club,table)){json(res,403,{ok:false,error:'table_limit_exceeded'});return;}
    const key=keyOf(club,table);
    res.writeHead(200,{
      'Content-Type':'text/event-stream; charset=utf-8',
      'Cache-Control':'no-cache, no-transform',
      'Connection':'keep-alive',
      'Access-Control-Allow-Origin':ALLOW_ORIGIN
    });
    res.write('retry: 2500\n\n');
    if(store.rooms[key]) res.write('event: state\ndata: '+JSON.stringify(store.rooms[key])+'\n\n');
    if(!clients.has(key)) clients.set(key,new Set());
    clients.get(key).add(res);
    const beat=setInterval(()=>{try{res.write(': ping\n\n')}catch{}},20000);
    req.on('close',()=>{clearInterval(beat);clients.get(key)?.delete(res);if(clients.get(key)?.size===0)clients.delete(key);});
    return;
  }

  const clubMatch=url.pathname.match(/^\/api\/clubs\/([^/]+)$/);
  if(clubMatch && req.method==='GET'){
    const club=safePart(clubMatch[1]);
    if(!authorizedForClub(req,url,club)){json(res,401,{ok:false,error:'license_invalid_or_expired'});return;}
    const rooms=Object.values(store.rooms).filter(r=>r.clubId===club).map(roomSummary).sort((a,b)=>a.table.localeCompare(b.table,'zh-CN'));
    json(res,200,{ok:true,clubId:club,rooms,license:publicLicense(store.licenses[club]),updatedAt:Date.now()});return;
  }

  json(res,404,{ok:false,error:'not_found'});
});

server.listen(PORT,HOST,()=>console.log(`SAGI CHINA SYNC listening on http://${HOST}:${PORT}`));
