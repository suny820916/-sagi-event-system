(()=>{'use strict';
const C=window.SAGI_CORE;if(!C)return;
const q=C.q,note=C.note,save=C.save,uid=C.uid,esc=C.esc,S=()=>C.state;

const CLOUD_URL='https://sagi-cloud-bridge-suny820916.onrender.com';
const DEPLOY_URL='https://render.com/deploy?repo=https://github.com/suny820916/-sagi-event-system';
const KEYS={
 engine:'sagi_download_engine_v1',
 cloudToken:'sagi_cloud_bridge_token_v2',
 localUrl:'sagi_local_bridge_url_v1'
};
const DIRECT_RE=/\.(mp4|mov|webm|m4v|ogg)(?:$|[?#])/i;
let currentStatus='等待粘贴 Instagram 链接。';
let activePoll=null;

function normalize(v){
 const s=String(v||'').trim();if(!s)return'';
 try{const u=new URL(s);return /^https?:$/.test(u.protocol)?u.toString():''}catch(e){return''}
}
function isInstagram(url){
 try{const h=new URL(url).hostname.toLowerCase().replace(/^www\./,'');return h==='instagram.com'||h.endsWith('.instagram.com')}
 catch(e){return false}
}
function safeName(url,title){
 let base=String(title||'').trim()||'SAGI_INS_VIDEO';
 base=base.replace(/[\\/:*?"<>|]+/g,'_').replace(/\s+/g,' ').trim().slice(0,90)||'SAGI_INS_VIDEO';
 if(!/\.(mp4|mov|webm|m4v|ogg)$/i.test(base))base+='.mp4';
 return base
}
function setStatus(msg,kind=''){
 currentStatus=msg;
 const el=q('downloadStatus');if(el){el.textContent=msg;el.className='downloadStatus '+kind}
}
function setProgress(show,label='准备中',pct=0){
 const box=q('downloadProgress'),bar=q('downloadProgressBar'),p=q('downloadProgressPct'),l=q('downloadProgressLabel');
 if(!box)return;
 box.hidden=!show;
 if(l)l.textContent=label;
 const n=Math.max(0,Math.min(100,Number(pct)||0));
 if(p)p.textContent=Math.round(n)+'%';
 if(bar)bar.style.width=n+'%';
}
function current(){
 const url=normalize(q('downloadUrl')?.value),title=(q('downloadTitle')?.value||'').trim();
 return{url,title,direct:DIRECT_RE.test(url),instagram:isInstagram(url)}
}
function engine(){return localStorage.getItem(KEYS.engine)||'cloud'}
function cloudToken(){return localStorage.getItem(KEYS.cloudToken)||''}
function localUrl(){return (q('downloadBridgeUrl')?.value||localStorage.getItem(KEYS.localUrl)||'').trim().replace(/\/+$/,'')}

function setCloudState(state,msg=''){
 const badge=q('cloudActivationBadge'),title=q('cloudActivationTitle'),desc=q('cloudActivationDesc'),btn=q('cloudActivateBtn');
 if(!badge||!title||!desc||!btn)return;
 badge.className='pill '+(state==='active'?'good':state==='checking'?'warn':'warn');
 if(state==='active'){
   badge.textContent='已激活';title.textContent='SAGI CLOUD 已连接';desc.textContent='5G / Wi‑Fi 都可以直接下载 INS 视频，不需要电脑地址、Cloud URL 或 Token。';btn.textContent='检测云端';
 }else if(state==='checking'){
   badge.textContent='检测中';title.textContent='正在连接 SAGI CLOUD';desc.textContent=msg||'正在检测云端服务和自动绑定凭证…';btn.textContent='检测中…';
 }else{
   badge.textContent='未激活';title.textContent='首次使用，激活一次即可';desc.textContent=msg||'点“激活 SAGI CLOUD”。如果云端还没部署，会自动进入一键部署页面；部署完成后回来再点一次即可自动绑定。';btn.textContent='激活 SAGI CLOUD';
 }
}

async function activateCloud(openDeploy=true){
 setCloudState('checking');
 setStatus('正在检测 SAGI CLOUD…','');
 try{
   const h=await fetch(CLOUD_URL+'/health',{cache:'no-store'});
   const hj=await h.json().catch(()=>({}));
   if(!h.ok||!hj.ok||!hj.configured)throw new Error('CLOUD_NOT_READY');

   const r=await fetch(CLOUD_URL+'/api/activate',{
     method:'POST',
     headers:{'Content-Type':'application/json'},
     body:'{}',
     cache:'no-store'
   });
   const j=await r.json().catch(()=>({}));
   if(!r.ok||!j.ok||!j.token)throw new Error(j.error||('HTTP '+r.status));
   localStorage.setItem(KEYS.cloudToken,j.token);
   localStorage.setItem(KEYS.engine,'cloud');
   setEngine('cloud',false);
   setCloudState('active');
   setStatus('SAGI CLOUD 激活成功。以后直接粘贴 INS 链接 → 下载。','good');
   note('SAGI CLOUD 已激活');
   return true
 }catch(e){
   localStorage.removeItem(KEYS.cloudToken);
   setCloudState('inactive','云端还未部署或尚未就绪。先完成一次部署，之后 CONTENT OS 会自动绑定。');
   setStatus('SAGI CLOUD 尚未上线。点“激活 SAGI CLOUD”进入一键部署；部署完成后回来再点一次。','warn');
   if(openDeploy)window.open(DEPLOY_URL,'_blank','noopener');
   return false
 }
}

function setEngine(v,announce=true){
 if(!['cloud','local'].includes(v))return;
 localStorage.setItem(KEYS.engine,v);
 document.querySelectorAll('[data-download-engine]').forEach(b=>b.classList.toggle('active',b.dataset.downloadEngine===v));
 if(q('downloadEngineBadge'))q('downloadEngineBadge').textContent=v.toUpperCase();
 if(announce)setStatus(v==='cloud'?'CLOUD 模式：5G / Wi‑Fi 直接下载，不需要电脑地址。':'LOCAL 备用模式：需要手机与电脑在同一 Wi‑Fi。','good')
}
function saveLocal(){
 const v=localUrl();
 if(!/^https?:\/\//i.test(v)){setStatus('LOCAL 地址格式不正确。示例：http://192.168.1.8:8765','bad');return}
 localStorage.setItem(KEYS.localUrl,v);setStatus('LOCAL Bridge 地址已保存。','good');note('LOCAL Bridge 地址已保存')
}
async function testLocal(){
 const base=localUrl();
 if(!base){setStatus('请先填写 LOCAL Bridge URL。','warn');return}
 setStatus('正在测试 LOCAL Bridge…','');
 try{
   const r=await fetch(base+'/health',{cache:'no-store'}),j=await r.json();
   if(!r.ok||!j.ok)throw new Error(j.error||'连接失败');
   setStatus('SAGI LOCAL BRIDGE 已连接 · READY','good')
 }catch(e){setStatus('LOCAL Bridge 连接失败：'+(e.message||e),'bad')}
}
function preview(){
 const x=current(),video=q('downloadPreview');
 if(!x.url){setStatus('请粘贴完整的 Instagram Reel / Post 地址。','bad');return}
 if(x.instagram){
   if(video){video.removeAttribute('src');video.load()}
   setStatus('Instagram 链接识别成功。','good');return
 }
 if(x.direct){
   if(video){video.src=x.url;video.load()}
   setStatus('已识别普通视频直链，可以直接下载。','good');return
 }
 setStatus('当前不是 Instagram 链接，也不是 MP4 / MOV / WEBM 直链。','warn')
}
function remember(x){
 S().downloadItems=S().downloadItems||[];
 S().downloadItems.unshift({id:uid('dl'),url:x.url,title:x.title||safeName(x.url,''),createdAt:Date.now(),engine:engine()});
 S().downloadItems=S().downloadItems.slice(0,20);save();renderHistory()
}
function directFile(x){
 const a=document.createElement('a');a.href=x.url;a.download=safeName(x.url,x.title);a.target='_blank';a.rel='noopener';document.body.appendChild(a);a.click();a.remove();
 remember(x);setStatus('已发起下载。','good');note('视频下载已启动')
}
function localInstagram(x){
 const base=localUrl();
 if(!base){setStatus('LOCAL 备用模式尚未设置电脑地址。请打开“备用设置”。','warn');return}
 const href=base+'/download?url='+encodeURIComponent(x.url)+'&name='+encodeURIComponent(safeName(x.url,x.title));
 remember(x);setProgress(true,'LOCAL 解析中',35);setStatus('正在交给 SAGI LOCAL BRIDGE…','good');
 const a=document.createElement('a');a.href=href;a.target='_blank';a.rel='noopener';document.body.appendChild(a);a.click();a.remove();
 setTimeout(()=>setProgress(false),3500)
}
async function ensureCloud(){
 if(cloudToken())return true;
 return await activateCloud(false)
}
async function cloudInstagram(x){
 if(!(await ensureCloud())){setStatus('SAGI CLOUD 尚未激活。先点上方“激活 SAGI CLOUD”。','warn');return}
 const token=cloudToken();
 if(activePoll){clearTimeout(activePoll);activePoll=null}
 setProgress(true,'创建云端任务',8);setStatus('正在创建 SAGI CLOUD 下载任务…','good');
 try{
   const r=await fetch(CLOUD_URL+'/api/jobs',{
     method:'POST',
     headers:{'Content-Type':'application/json','Authorization':'Bearer '+token},
     body:JSON.stringify({url:x.url,name:safeName(x.url,x.title)})
   });
   const j=await r.json().catch(()=>({}));
   if(r.status===401){localStorage.removeItem(KEYS.cloudToken);setCloudState('inactive','云端凭证需要重新激活。');throw new Error('请重新激活 SAGI CLOUD')}
   if(!r.ok||!j.ok)throw new Error(j.error||('HTTP '+r.status));
   remember(x);setProgress(true,'云端解析 Instagram',20);pollCloud(j.job.id,token,0)
 }catch(e){setProgress(false);setStatus('CLOUD 下载任务失败：'+(e.message||e),'bad')}
}
async function pollCloud(id,token,attempt){
 if(attempt>180){setProgress(false);setStatus('云端解析超时，请稍后重试。','bad');return}
 try{
   const r=await fetch(CLOUD_URL+'/api/jobs/'+encodeURIComponent(id),{
     headers:{'Authorization':'Bearer '+token},cache:'no-store'
   });
   const j=await r.json().catch(()=>({}));
   if(r.status===401){localStorage.removeItem(KEYS.cloudToken);setCloudState('inactive','云端凭证需要重新激活。');throw new Error('请重新激活 SAGI CLOUD')}
   if(!r.ok||!j.ok)throw new Error(j.error||('HTTP '+r.status));
   const job=j.job||{};
   if(job.status==='ready'&&job.downloadUrl){
     setProgress(true,'视频已就绪',100);setStatus('解析完成，正在直接下载 MP4…','good');
     const a=document.createElement('a');a.href=job.downloadUrl;a.target='_blank';a.rel='noopener';document.body.appendChild(a);a.click();a.remove();
     setTimeout(()=>setProgress(false),5000);note('INS 视频已解析完成');return
   }
   if(job.status==='failed'){setProgress(false);setStatus('云端解析失败：'+(job.error||'Instagram 未返回视频'),'bad');return}
   const pct=Math.min(92,20+attempt*2);
   setProgress(true,job.status==='queued'?'云端排队':'正在下载 Instagram 视频',pct);
   activePoll=setTimeout(()=>pollCloud(id,token,attempt+1),1500)
 }catch(e){
   if(attempt<5){activePoll=setTimeout(()=>pollCloud(id,token,attempt+1),1800);return}
   setProgress(false);setStatus('云端连接中断：'+(e.message||e),'bad')
 }
}
async function download(){
 const x=current();
 if(!x.url){setStatus('请先粘贴有效链接。','bad');return}
 if(x.direct&&!x.instagram){directFile(x);return}
 if(!x.instagram){setStatus('当前直连下载先支持 Instagram Reel / Post。','warn');return}
 if(engine()==='local')localInstagram(x);else await cloudInstagram(x)
}
function openOriginal(){
 const x=current();if(!x.url){setStatus('请先粘贴有效链接。','bad');return}
 window.open(x.url,'_blank','noopener')
}
function sendToJob(){
 const x=current();if(!x.url){setStatus('请先粘贴有效视频链接。','bad');return}
 S().videoJobs=S().videoJobs||[];
 const title=x.title||'Instagram 视频 · AI剪辑任务';
 S().videoJobs.unshift({
   id:uid('job'),title,type:'hot15',typeLabel:'15秒热点版',duration:15,status:'WAITING_FOR_BRIDGE',createdAt:Date.now(),
   source:'download',brief:'Instagram 授权素材 → SAGI Download Bridge → VideoHighlighter / Cutpoint；前1秒优先最强镜头，输出9:16。',
   requiredTags:['highlight','goal','save','celebration','crowd'],
   sourcePayload:{download:{url:x.url,title,engine:engine(),instagram:x.instagram}},revisions:[],resultUrl:'',approvedAt:0
 });
 save();remember(x);note('已送入 AI VIDEO JOB');C.switchView('videojobs')
}
function remove(id){S().downloadItems=(S().downloadItems||[]).filter(x=>x.id!==id);save();renderHistory()}
function useHistory(id,action){
 const x=(S().downloadItems||[]).find(a=>a.id===id);if(!x)return;
 if(q('downloadUrl'))q('downloadUrl').value=x.url;if(q('downloadTitle'))q('downloadTitle').value=x.title||'';
 if(action==='download')download();else preview()
}
function renderHistory(){
 const host=q('downloadHistory');if(!host)return;const list=S().downloadItems||[];
 host.innerHTML=list.length?list.map(x=>'<div class="downloadHistoryRow"><div><b>'+esc(x.title||'视频')+'</b><span>'+esc(x.url)+'</span></div><div class="downloadHistoryActions"><button class="btn" data-dl-use="'+x.id+'" type="button">载入</button><button class="btn blue" data-dl-again="'+x.id+'" type="button">再下载</button><button class="btn danger" data-dl-del="'+x.id+'" type="button">删除</button></div></div>').join(''):'<div class="empty">还没有下载记录。</div>';
 host.querySelectorAll('[data-dl-use]').forEach(b=>b.onclick=()=>useHistory(b.dataset.dlUse,'preview'));
 host.querySelectorAll('[data-dl-again]').forEach(b=>b.onclick=()=>useHistory(b.dataset.dlAgain,'download'));
 host.querySelectorAll('[data-dl-del]').forEach(b=>b.onclick=()=>remove(b.dataset.dlDel))
}
function render(){
 if(q('downloadBridgeUrl')&&!q('downloadBridgeUrl').value)q('downloadBridgeUrl').value=localStorage.getItem(KEYS.localUrl)||'';
 setEngine(engine(),false);renderHistory();setCloudState(cloudToken()?'active':'inactive');
 const s=q('downloadStatus');if(s&&!s.textContent.trim())setStatus(currentStatus)
}

document.querySelectorAll('[data-download-engine]').forEach(b=>b.onclick=()=>setEngine(b.dataset.downloadEngine));
if(q('cloudActivateBtn'))q('cloudActivateBtn').onclick=()=>activateCloud(true);
if(q('cloudDeployBtn'))q('cloudDeployBtn').onclick=()=>window.open(DEPLOY_URL,'_blank','noopener');
if(q('downloadPreviewBtn'))q('downloadPreviewBtn').onclick=preview;
if(q('downloadStartBtn'))q('downloadStartBtn').onclick=download;
if(q('downloadOpenBtn'))q('downloadOpenBtn').onclick=openOriginal;
if(q('downloadToJobBtn'))q('downloadToJobBtn').onclick=sendToJob;
if(q('downloadCommandBtn'))q('downloadCommandBtn').onclick=saveLocal;
if(q('downloadTestBtn'))q('downloadTestBtn').onclick=testLocal;
if(q('downloadUrl'))q('downloadUrl').addEventListener('keydown',e=>{if(e.key==='Enter')preview()});

window.SAGI_DOWNLOADER={render,preview,download,setEngine,activateCloud,sendToJob};
render();
})();