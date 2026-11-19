(()=>{const CONFIG_KEY='sagi-kit-cloud-config',QUEUE_KEY='sagi-kit-sync-queue',STATUS_KEY='sagi-kit-sync-status',DEVICE_KEY='sagi-kit-device-id';
const read=(k,d)=>{try{return JSON.parse(localStorage.getItem(k)||JSON.stringify(d))}catch(e){return d}};
const write=(k,v)=>{try{localStorage.setItem(k,JSON.stringify(v));return true}catch(e){return false}};
function deviceId(){let id=localStorage.getItem(DEVICE_KEY);if(!id){id=(crypto&&crypto.randomUUID)?crypto.randomUUID():'sagi-'+Date.now()+'-'+Math.random().toString(36).slice(2);localStorage.setItem(DEVICE_KEY,id)}return id}
function config(){return Object.assign({enabled:false,endpoint:'',token:''},read(CONFIG_KEY,{}))}
function cleanEndpoint(v){return String(v||'').trim().replace(/\/+$/,'')}
function setConfig(next){const c=Object.assign(config(),next);c.endpoint=cleanEndpoint(c.endpoint);write(CONFIG_KEY,c);notify();return c}
function queue(){return read(QUEUE_KEY,[])}
function status(){const q=queue(),c=config(),s=read(STATUS_KEY,{});return Object.assign({enabled:c.enabled&&!!c.endpoint,pending:q.length,lastSyncedAt:null,lastError:''},s,{enabled:c.enabled&&!!c.endpoint,pending:q.length})}
function setStatus(p){write(STATUS_KEY,Object.assign(status(),p));notify()}
function notify(){try{window.dispatchEvent(new CustomEvent('sagi-cloud-status',{detail:status()}))}catch(e){}}
function enqueue(order){if(!order||!order.orderCode)return false;let q=queue();if(!q.some(x=>x.order&&x.order.orderCode===order.orderCode))q.push({order,queuedAt:new Date().toISOString(),attempts:0,lastError:''});q=q.slice(-200);const ok=write(QUEUE_KEY,q);notify();return ok}
function headers(){const c=config(),h={'Content-Type':'application/json','X-SAGI-Device':deviceId()};if(c.token)h.Authorization='Bearer '+c.token;return h}
async function ping(){const c=config();if(!c.enabled||!c.endpoint)throw new Error('云端备份尚未启用');const ctl=new AbortController(),tm=setTimeout(()=>ctl.abort(),7000);try{const r=await fetch(c.endpoint+'/api/health',{headers:headers(),cache:'no-store',signal:ctl.signal});if(!r.ok)throw new Error('服务器返回 '+r.status);return true}finally{clearTimeout(tm)}}
let flushing=false;
async function flush(){const c=config();if(flushing||!c.enabled||!c.endpoint||!navigator.onLine)return status();let q=queue();if(!q.length){setStatus({lastError:''});return status()}flushing=true;try{for(let i=0;i<q.length;){const item=q[i],ctl=new AbortController(),tm=setTimeout(()=>ctl.abort(),10000);try{const r=await fetch(c.endpoint+'/api/kit/orders',{method:'POST',headers:headers(),body:JSON.stringify(item.order),signal:ctl.signal});clearTimeout(tm);if(!r.ok)throw new Error('同步失败 '+r.status);q.splice(i,1);write(QUEUE_KEY,q);setStatus({lastSyncedAt:new Date().toISOString(),lastError:''})}catch(e){clearTimeout(tm);item.attempts=(item.attempts||0)+1;item.lastError=e&&e.message?e.message:'网络错误';write(QUEUE_KEY,q);setStatus({lastError:item.lastError});break}}}finally{flushing=false;notify()}return status()}
window.SAGICloud={config,setConfig,status,enqueue,flush,ping,deviceId};
window.addEventListener('online',()=>flush());
setTimeout(()=>{notify();flush()},350);
})();