(function(g){
'use strict';
function clean(s){return String(s||'').trim().replace(/\/$/,'')}
function cfg(overrides){
  var base=g.SAGI_CLOUD||{};
  return Object.assign({url:'',key:'',eventSlug:''},base,overrides||{});
}
async function rpc(name,args,overrides){
  var c=cfg(overrides);
  if(!c.url||!c.key) throw new Error('云数据库尚未配置 Project URL / Publishable Key');
  var r=await fetch(clean(c.url)+'/rest/v1/rpc/'+name,{
    method:'POST',
    headers:{'Content-Type':'application/json','apikey':c.key,'Authorization':'Bearer '+c.key},
    body:JSON.stringify(args||{})
  });
  var text=await r.text(),data=null;
  try{data=text?JSON.parse(text):null}catch(e){data=text}
  if(!r.ok){
    var msg=(data&&data.message)||text||('HTTP '+r.status);
    var err=new Error(msg);err.status=r.status;err.body=data;throw err;
  }
  return data;
}
async function getEvent(slug,overrides){
  return rpc('sagi_get_event',{p_slug:slug},overrides);
}
async function claimEvent(slug,token,payload,overrides){
  return rpc('sagi_claim_event',{p_slug:slug,p_token:token,p_payload:payload},overrides);
}
async function saveEvent(slug,token,payload,revision,overrides){
  return rpc('sagi_save_event',{p_slug:slug,p_token:token,p_payload:payload,p_expected_revision:revision==null?null:revision},overrides);
}
g.SagiCloud={cfg:cfg,rpc:rpc,getEvent:getEvent,claimEvent:claimEvent,saveEvent:saveEvent};
})(window);