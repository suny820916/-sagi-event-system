import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const PORT = Number(process.env.PORT || 8787);
const HOST = process.env.HOST || '0.0.0.0';
const TOKEN = process.env.SAGI_SYNC_TOKEN || '';
const ALLOW_ORIGIN = process.env.SAGI_ALLOW_ORIGIN || '*';
const DATA_FILE = process.env.SAGI_DATA_FILE || path.join(path.dirname(fileURLToPath(import.meta.url)), 'data.json');

let store = { rooms: {} };
try {
  if (fs.existsSync(DATA_FILE)) store = JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
} catch (e) {
  console.error('Failed to load data file:', e.message);
}
if (!store.rooms) store.rooms = {};

const clients = new Map();
let persistTimer = null;

function cors(res) {
  res.setHeader('Access-Control-Allow-Origin', ALLOW_ORIGIN);
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, X-SAGI-Token');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  res.setHeader('Access-Control-Max-Age', '86400');
}
function json(res, code, body) {
  cors(res);
  res.writeHead(code, {'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'});
  res.end(JSON.stringify(body));
}
function authorized(req, url) {
  if (!TOKEN) return true;
  return req.headers['x-sagi-token'] === TOKEN || url.searchParams.get('token') === TOKEN;
}
function safePart(v) {
  return decodeURIComponent(v || '').replace(/[^\p{L}\p{N}_\-.]/gu, '').slice(0,64);
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
    req.on('data',c=>{ total+=c.length; if(total>limit){reject(new Error('payload_too_large'));req.destroy();return;} chunks.push(c); });
    req.on('end',()=>resolve(Buffer.concat(chunks).toString('utf8')));
    req.on('error',reject);
  });
}
function roomSummary(room) {
  const s=room?.state||{};
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
  if(url.pathname==='/health'){json(res,200,{ok:true,service:'SAGI CHINA SYNC',version:'1.0.0',time:Date.now()});return;}
  if(!authorized(req,url)){json(res,401,{ok:false,error:'unauthorized'});return;}

  const roomMatch=url.pathname.match(/^\/api\/rooms\/([^/]+)\/([^/]+)$/);
  if(roomMatch){
    const club=safePart(roomMatch[1]), table=safePart(roomMatch[2]);
    if(!club||!table){json(res,400,{ok:false,error:'invalid_room'});return;}
    const key=keyOf(club,table);
    if(req.method==='GET'){
      const room=store.rooms[key];
      json(res,200,{ok:true,room:room||null}); return;
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
        store.rooms[key]=room;schedulePersist();notify(key,room);json(res,200,{ok:true,room});return;
      }catch(e){json(res,e.message==='payload_too_large'?413:400,{ok:false,error:e.message});return;}
    }
  }

  const eventsMatch=url.pathname.match(/^\/api\/rooms\/([^/]+)\/([^/]+)\/events$/);
  if(eventsMatch && req.method==='GET'){
    const club=safePart(eventsMatch[1]),table=safePart(eventsMatch[2]),key=keyOf(club,table);
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
    const rooms=Object.values(store.rooms).filter(r=>r.clubId===club).map(roomSummary).sort((a,b)=>a.table.localeCompare(b.table,'zh-CN'));
    json(res,200,{ok:true,clubId:club,rooms,updatedAt:Date.now()});return;
  }

  json(res,404,{ok:false,error:'not_found'});
});

server.listen(PORT,HOST,()=>console.log(`SAGI CHINA SYNC listening on http://${HOST}:${PORT}`));
