(function(root){
'use strict';
const VERSION='4.32.0-rc.2';
const EVENT_TYPES=Object.freeze(['CLEAR_EVENT','GOAL','YELLOW','RED','SUB','HALF_TIME','FULL_TIME','MVP','REPLAY_STINGER']);
const TOKENS=Object.freeze({
  bg:'#07090d',
  panel:'#11151c',
  line:'#2b3340',
  text:'#f4f0e8',
  muted:'#8f97a5',
  gold:'#d8b55b',
  green:'#72c79a',
  blue:'#39a7db',
  yellow:'#f2d536',
  red:'#e33440',
  homeFallback:'#d8b55b',
  awayFallback:'#4c7dff',
  motionEnterMs:460,
  motionExitMs:300
});
const HOLD_MS=Object.freeze({
  GOAL:5600,
  YELLOW:5200,
  RED:5200,
  SUB:6500,
  HALF_TIME:6500,
  FULL_TIME:9000,
  MVP:9000,
  REPLAY_STINGER:1520,
  CLEAR_EVENT:0
});
const ALIAS=Object.freeze({
  SUBSTITUTION:'SUB',
  SUBSTITUTE:'SUB',
  YELLOW_CARD:'YELLOW',
  RED_CARD:'RED',
  HT:'HALF_TIME',
  FT:'FULL_TIME'
});
function safeText(value,max=120){
  const s=String(value==null?'':value).replace(/[\u0000-\u001f\u007f]/g,' ').replace(/\s+/g,' ').trim();
  return s.slice(0,Math.max(0,Number(max)||0));
}
function validHex(value,fallback=''){
  const s=safeText(value,16);
  return /^#[0-9a-fA-F]{6}$/.test(s)?s:fallback;
}
function normalizeSide(value){
  return String(value||'').toUpperCase()==='AWAY'?'AWAY':'HOME';
}
function normalizePlayer(p){
  if(!p||typeof p!=='object') return null;
  return {
    id:safeText(p.id,80),
    name:safeText(p.name,80),
    number:safeText(p.number,12),
    position:safeText(p.position||p.role,24),
    photo:safeText(p.photo,2048)
  };
}
function normalizeType(value){
  let t=safeText(value,40).toUpperCase();
  if(ALIAS[t]) t=ALIAS[t];
  return EVENT_TYPES.includes(t)?t:'CLEAR_EVENT';
}
function normalizeEvent(raw,context={}){
  if(raw==null) return null;
  if(typeof raw!=='object') return {type:'CLEAR_EVENT',__signatureVersion:VERSION,__rejectedType:safeText(raw,40)};
  const originalType=safeText(raw.type,40).toUpperCase();
  const type=normalizeType(originalType);
  const side=normalizeSide(raw.side);
  const teamFallback=side==='AWAY'?safeText(context.away,80):safeText(context.home,80);
  const e={
    type,
    side,
    team:safeText(raw.team||teamFallback,80),
    at:safeText(raw.at,24),
    eventId:safeText(raw.eventId,128),
    sequence:(Number.isSafeInteger(raw.sequence)&&raw.sequence>=0)?raw.sequence:null,
    __signatureVersion:VERSION
  };
  if(type==='CLEAR_EVENT'){
    if(originalType && originalType!=='CLEAR_EVENT') e.__rejectedType=originalType;
    return e;
  }
  if(type==='GOAL'||type==='YELLOW'||type==='RED'){
    e.player=normalizePlayer(raw.player);
  }
  if(type==='SUB'){
    e.on=normalizePlayer(raw.on);
    e.off=normalizePlayer(raw.off);
  }
  if(type==='HALF_TIME'||type==='FULL_TIME'){
    e.home=safeText(raw.home||context.home,80);
    e.away=safeText(raw.away||context.away,80);
    e.homeScore=Math.max(0,Math.floor(Number(raw.homeScore)||0));
    e.awayScore=Math.max(0,Math.floor(Number(raw.awayScore)||0));
  }
  if(type==='MVP'){
    e.player=normalizePlayer(raw.player);
    e.score=safeText(raw.score,40);
  }
  if(type==='REPLAY_STINGER'){
    e.phase=String(raw.phase||'IN').toUpperCase()==='OUT'?'OUT':'IN';
    e.title=safeText(raw.title||(e.phase==='OUT'?'BACK TO LIVE':'INSTANT REPLAY'),80);
    e.label=safeText(raw.label||(e.phase==='OUT'?'回到比赛':'精彩回放'),40);
  }
  return e;
}
function eventAccent(event,graphics={}){
  const type=normalizeType(event&&event.type);
  if(type==='YELLOW') return TOKENS.yellow;
  if(type==='RED') return TOKENS.red;
  if(type==='SUB') return TOKENS.blue;
  const side=normalizeSide(event&&event.side);
  return side==='AWAY'?validHex(graphics.awayColor,TOKENS.awayFallback):validHex(graphics.homeColor,TOKENS.homeFallback);
}
function holdMs(type,fallback=5200){
  const t=normalizeType(type);
  return Object.prototype.hasOwnProperty.call(HOLD_MS,t)?HOLD_MS[t]:Math.max(0,Number(fallback)||0);
}
function eventKey(event){
  const e=normalizeEvent(event)||{type:'CLEAR_EVENT'};
  if(e.eventId) return 'id|'+e.eventId;
  if(e.sequence!==null&&e.sequence!==undefined) return 'seq|'+String(e.sequence);
  // Fail open for legacy events without a reliable identity.
  // Revision/command guards still prevent stale rollback; never collapse two real events by metadata guesswork.
  return '';
}
const api=Object.freeze({VERSION,TOKENS,EVENT_TYPES,HOLD_MS,safeText,validHex,normalizeSide,normalizeType,normalizeEvent,eventAccent,holdMs,eventKey});
root.SAGISignatureCore=api;
})(typeof window!=='undefined'?window:globalThis);
