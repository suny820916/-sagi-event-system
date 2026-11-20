(()=>{const CONFIG_KEY='sagi-kit-cloud-config',QUEUE_KEY='sagi-kit-sync-queue',STATUS_KEY='sagi-kit-sync-status',DEVICE_KEY='sagi-kit-device-id';
const COMPLIANCE_MODE='cn-hk-minimal-v1';
const read=(k,d)=>{try{return JSON.parse(localStorage.getItem(k)||JSON.stringify(d))}catch(e){return d}};
const write=(k,v)=>{try{localStorage.setItem(k,JSON.stringify(v));return true}catch(e){return false}};
function deviceId(){let id=localStorage.getItem(DEVICE_KEY);if(!id){id=(window.crypto&&window.crypto.randomUUID)?window.crypto.randomUUID():'sagi-'+Date.now()+'-'+Math.random().toString(36).slice(2);localStorage.setItem(DEVICE_KEY,id)}return id}
function config(){return Object.assign({enabled:false,endpoint:'',token:'',complianceMode:COMPLIANCE_MODE},read(CONFIG_KEY,{}),{complianceMode:COMPLIANCE_MODE})}
function cleanEndpoint(v){return String(v||'').trim().replace(/\/+$/,'')}
function setConfig(next){const c=Object.assign(config(),next,{complianceMode:COMPLIANCE_MODE});c.endpoint=cleanEndpoint(c.endpoint);write(CONFIG_KEY,c);notify();return c}
function sanitizeOrder(order){
 if(!order||!order.orderCode)return null;
 const p=order.product||{},prod=order.production||{},del=order.delivery||{},roster=Array.isArray(order.roster)?order.roster:[];
 const issues=Array.isArray(del.issues)?del.issues:[];
 const youth=p.ageGroup==='child';
 return {
  schema:'SAGI-KIT-CLOUD-MIN-1',
  version:1,
  compliance:{mode:COMPLIANCE_MODE,redacted:true,youthRestricted:youth},
  orderCode:String(order.orderCode),
  createdAt:order.createdAt||null,
  status:order.status||'待确认',
  statusUpdatedAt:order.statusUpdatedAt||null,
  quantity:roster.length,
  product:youth?{
   sagiCode:p.sagiCode||''
  }:{
   sagiCode:p.sagiCode||'',
   color:p.color||'',
   collar:p.collar||'',
   fabric:p.fabric||''
  },
  production:youth?{
   stage:prod.stage||'',
   updatedAt:prod.updatedAt||null
  }:{
   stage:prod.stage||'',
   dueDate:prod.dueDate||'',
   updatedAt:prod.updatedAt||null
  },
  delivery:youth?{
   stage:del.stage||'',
   updatedAt:del.updatedAt||null
  }:{
   stage:del.stage||'',
   deliveredAt:del.deliveredAt||'',
   signedAt:del.signedAt||'',
   reorderAt:del.reorderAt||'',
   unresolvedIssueCount:issues.filter(x=>x&&!x.resolved).length,
   updatedAt:del.updatedAt||null
  },
  updatedAt:del.updatedAt||prod.updatedAt||order.statusUpdatedAt||order.createdAt||null
 };
}
function forbiddenCloudFields(payload){
 const raw=JSON.stringify(payload||{}).toLowerCase();
 return ['"customer"','"roster"','"contact"','"phone"','"signedby"','"logopreview"','"sponsor"','"note"','"desc"','sagi-kit-private-cost-v1','costprice','suppliermapping','factorycontact'].filter(k=>raw.includes(k));
}
function queue(){const q=read(QUEUE_KEY,[]);return Array.isArray(q)?q:[]}
function migrateQueue(){
 const old=queue();let changed=false;
 const next=old.map(item=>{
  if(item&&item.cloud&&item.orderCode)return item;
  const source=item&&item.order?item.order:item,cloud=sanitizeOrder(source);
  if(!cloud||!source||!source.orderCode)return null;
  changed=true;
  return {orderCode:source.orderCode,cloud,queuedAt:item&&item.queuedAt||new Date().toISOString(),attempts:item&&item.attempts||0,lastError:item&&item.lastError||''}
 }).filter(Boolean).slice(-200);
 if(changed||next.length!==old.length)write(QUEUE_KEY,next);
 return next
}
function status(){const q=queue(),c=config(),s=read(STATUS_KEY,{});return Object.assign({enabled:c.enabled&&!!c.endpoint,pending:q.length,lastSyncedAt:null,lastError:'',complianceMode:COMPLIANCE_MODE},s,{enabled:c.enabled&&!!c.endpoint,pending:q.length,complianceMode:COMPLIANCE_MODE})}
function setStatus(p){write(STATUS_KEY,Object.assign(status(),p));notify()}
function notify(){try{window.dispatchEvent(new CustomEvent('sagi-cloud-status',{detail:status()}))}catch(e){}}
function enqueue(order){
 if(!order||!order.orderCode)return false;
 const cloud=sanitizeOrder(order);if(!cloud)return false;
 const forbidden=forbiddenCloudFields(cloud);if(forbidden.length){setStatus({lastError:'合规拦截：发现禁止上传字段'});return false}
 let q=queue();const i=q.findIndex(x=>x.orderCode===order.orderCode||x.order&&x.order.orderCode===order.orderCode);
 const item={orderCode:order.orderCode,cloud,queuedAt:new Date().toISOString(),attempts:i>=0?(q[i].attempts||0):0,lastError:''};
 if(i>=0)q[i]=item;else q.push(item);q=q.slice(-200);const ok=write(QUEUE_KEY,q);notify();return ok
}
function headers(){const c=config(),h={'Content-Type':'application/json','X-SAGI-Device':deviceId(),'X-SAGI-Privacy':COMPLIANCE_MODE};if(c.token)h.Authorization='Bearer '+c.token;return h}
async function ping(){const c=config();if(!c.enabled||!c.endpoint)throw new Error('云端备份尚未启用');const ctl=new AbortController(),tm=setTimeout(()=>ctl.abort(),7000);try{const r=await fetch(c.endpoint+'/api/health',{headers:headers(),cache:'no-store',signal:ctl.signal});if(!r.ok)throw new Error('服务器返回 '+r.status);return true}finally{clearTimeout(tm)}}
function payloadForItem(item){
 const candidate=item&&item.cloud?item.cloud:sanitizeOrder(item&&item.order?item.order:item);
 if(!candidate)return null;
 const forbidden=forbiddenCloudFields(candidate);if(forbidden.length)throw new Error('合规拦截：禁止上传个人/私有字段');
 return candidate
}
let flushing=false;
async function flush(){const c=config();if(flushing||!c.enabled||!c.endpoint||!navigator.onLine)return status();let q=queue();if(!q.length){setStatus({lastError:''});return status()}flushing=true;try{for(let i=0;i<q.length;){const item=q[i],ctl=new AbortController(),tm=setTimeout(()=>ctl.abort(),10000);try{const payload=payloadForItem(item);if(!payload)throw new Error('同步数据无效');const r=await fetch(c.endpoint+'/api/kit/orders',{method:'POST',headers:headers(),body:JSON.stringify(payload),signal:ctl.signal});clearTimeout(tm);if(!r.ok)throw new Error('同步失败 '+r.status);q.splice(i,1);write(QUEUE_KEY,q);setStatus({lastSyncedAt:new Date().toISOString(),lastError:''})}catch(e){clearTimeout(tm);item.attempts=(item.attempts||0)+1;item.lastError=e&&e.message?e.message:'网络错误';write(QUEUE_KEY,q);setStatus({lastError:item.lastError});break}}}finally{flushing=false;notify()}return status()}
function preview(order){const cloud=sanitizeOrder(order);return {cloud,forbidden:forbiddenCloudFields(cloud)}}
window.SAGICloud={config,setConfig,status,enqueue,flush,ping,deviceId,sanitizeOrder,preview,complianceMode:COMPLIANCE_MODE};
window.addEventListener('online',()=>flush());
migrateQueue();setTimeout(()=>{notify();flush()},350);
})();