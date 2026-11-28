(function(root){
'use strict';
const VERSION='4.33.0-rc.1';
const RESULTS=Object.freeze(['GOAL','MISS']);
function safeSide(v){return String(v||'').toUpperCase()==='AWAY'?'AWAY':'HOME'}
function safeResult(v){return String(v||'').toUpperCase()==='MISS'?'MISS':'GOAL'}
function safeId(v,max=128){return String(v==null?'':v).replace(/[\u0000-\u001f\u007f]/g,' ').trim().slice(0,max)}
function normalizeHistory(raw,firstSide='HOME',rounds=5){
 const seen=new Map(),out=[];
 firstSide=safeSide(firstSide);
 for(const x of Array.isArray(raw)?raw:[]){
  if(!x||typeof x!=='object')break;
  const kickId=safeId(x.kickId),side=String(x.side||'').toUpperCase(),result=String(x.result||'').toUpperCase();
  if(!['HOME','AWAY'].includes(side)||!RESULTS.includes(result))break;
  if(kickId&&seen.has(kickId)){
   const prior=seen.get(kickId);
   if(prior.side!==side||prior.result!==result)break;
   continue;
  }
  const expected=out.length%2===0?firstSide:firstSide==='HOME'?'AWAY':'HOME';
  if(side!==expected||evaluateBase({history:out,rounds}).finished)break;
  const entry={kickId,side,result,at:safeId(x.at,32)};
  if(kickId)seen.set(kickId,entry);
  out.push(entry);
 }
 return out;
}
function stats(state){
 const h=normalizeState(state||{}).history;
 const home=h.filter(x=>x.side==='HOME'),away=h.filter(x=>x.side==='AWAY');
 return {homeAttempts:home.length,awayAttempts:away.length,homeGoals:home.filter(x=>x.result==='GOAL').length,awayGoals:away.filter(x=>x.result==='GOAL').length};
}
function nextSide(state){
 const s=normalizeState(state);
 if(s.finished)return'';
 return s.history.length%2===0?s.firstSide:(s.firstSide==='HOME'?'AWAY':'HOME');
}
function currentRound(state){
 const st=stats(state);return Math.min(st.homeAttempts,st.awayAttempts)+1;
}
function suddenDeath(state){
 const s=normalizeState(state),st=stats(s);
 return Math.min(st.homeAttempts,st.awayAttempts)>=s.rounds||Math.max(st.homeAttempts,st.awayAttempts)>s.rounds;
}
function evaluate(state){
 const s=normalizeState(state||{});
 const st=stats(s),r=s.rounds;let winner='';
 if(st.homeAttempts<=r&&st.awayAttempts<=r){
  const remH=Math.max(0,r-st.homeAttempts),remA=Math.max(0,r-st.awayAttempts);
  if(st.homeGoals>st.awayGoals+remA)winner='HOME';
  else if(st.awayGoals>st.homeGoals+remH)winner='AWAY';
 }
 if(!winner&&st.homeAttempts===st.awayAttempts&&st.homeAttempts>=r&&st.homeGoals!==st.awayGoals){
  winner=st.homeGoals>st.awayGoals?'HOME':'AWAY';
 }
 return {...s,winner,finished:!!winner};
}
function normalizeState(raw={}){
 raw=raw&&typeof raw==='object'?raw:{};
 const rounds=[3,5].includes(Number(raw.rounds))?Number(raw.rounds):5;
 const base={started:!!raw.started,rounds,firstSide:safeSide(raw.firstSide),history:normalizeHistory(raw.history,raw.firstSide,rounds),winner:'',finished:false};
 const ev=evaluateBase(base);
 return {...base,winner:ev.winner,finished:ev.finished};
}
function evaluateBase(s){
 const st=statsRaw(s.history),r=s.rounds;let winner='';
 if(st.homeAttempts<=r&&st.awayAttempts<=r){
  const remH=Math.max(0,r-st.homeAttempts),remA=Math.max(0,r-st.awayAttempts);
  if(st.homeGoals>st.awayGoals+remA)winner='HOME';
  else if(st.awayGoals>st.homeGoals+remH)winner='AWAY';
 }
 if(!winner&&st.homeAttempts===st.awayAttempts&&st.homeAttempts>=r&&st.homeGoals!==st.awayGoals)winner=st.homeGoals>st.awayGoals?'HOME':'AWAY';
 return {winner,finished:!!winner};
}
function statsRaw(h){
 const home=h.filter(x=>x.side==='HOME'),away=h.filter(x=>x.side==='AWAY');
 return {homeAttempts:home.length,awayAttempts:away.length,homeGoals:home.filter(x=>x.result==='GOAL').length,awayGoals:away.filter(x=>x.result==='GOAL').length};
}
function applyKick(state,command={}){
 let s=normalizeState(state);
 const kickId=safeId(command.kickId);
 if(!kickId)return{state:s,accepted:false,deduped:false,reason:'MISSING_KICK_ID'};
 if(s.history.some(x=>x.kickId===kickId))return{state:s,accepted:true,deduped:true,reason:'DUPLICATE_KICK_ID'};
 if(s.finished)return{state:s,accepted:false,deduped:false,reason:'FINISHED'};
 const side=String(command.side||'').toUpperCase(),result=String(command.result||'').toUpperCase(),expected=nextSide(s);
 if(!['HOME','AWAY'].includes(side))return{state:s,accepted:false,deduped:false,reason:'INVALID_SIDE'};
 if(!RESULTS.includes(result))return{state:s,accepted:false,deduped:false,reason:'INVALID_RESULT'};
 if(side!==expected)return{state:s,accepted:false,deduped:false,reason:'WRONG_SIDE',expectedSide:expected};
 const history=s.history.concat({kickId,side,result,at:safeId(command.at,32)});
 s=normalizeState({...s,started:true,history});
 return{state:s,accepted:true,deduped:false,reason:'OK'};
}
function undo(state){
 const s=normalizeState(state);
 if(!s.history.length)return{state:s,undone:null,changed:false};
 const undone=s.history[s.history.length-1];
 return{state:normalizeState({...s,history:s.history.slice(0,-1)}),undone,changed:true};
}
function snapshot(state){
 const s=normalizeState(state),st=stats(s);
 return{...s,nextSide:nextSide(s),currentRound:currentRound(s),suddenDeath:suddenDeath(s),...st};
}
const api=Object.freeze({VERSION,RESULTS,safeSide,safeResult,normalizeHistory,normalizeState,stats,nextSide,currentRound,suddenDeath,evaluate,applyKick,undo,snapshot});
root.SAGIPenaltyCore=api;
})(typeof window!=='undefined'?window:globalThis);
