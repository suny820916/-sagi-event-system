(()=>{'use strict';
const C=window.SAGI_CORE;if(!C)return;
const q=C.q,note=C.note,save=C.save,uid=C.uid,esc=C.esc,S=()=>C.state;
const COBALT_URL='https://cobalt.tools/';

function normalize(v){
 const s=String(v||'').trim();if(!s)return'';
 try{const u=new URL(s);return /^https?:$/.test(u.protocol)?u.toString():''}catch(e){return''}
}
function isInstagram(url){
 try{const h=new URL(url).hostname.toLowerCase().replace(/^www\./,'');return h==='instagram.com'||h.endsWith('.instagram.com')}
 catch(e){return false}
}
function setStatus(msg,kind=''){
 const el=q('downloadStatus');if(el){el.textContent=msg;el.className='downloadStatus '+kind}
}
function current(){
 return{
   url:normalize(q('downloadUrl')?.value),
   title:(q('downloadTitle')?.value||'').trim()
 }
}
function remember(x){
 S().downloadItems=S().downloadItems||[];
 S().downloadItems.unshift({id:uid('dl'),url:x.url,title:x.title||'Instagram 视频',createdAt:Date.now()});
 S().downloadItems=S().downloadItems.slice(0,20);save();renderHistory()
}
async function download(){
 const x=current();
 if(!x.url){setStatus('请先粘贴 Instagram 链接。','bad');return}
 if(!isInstagram(x.url)){setStatus('当前不是有效的 Instagram 链接。','warn');return}
 try{
   await navigator.clipboard.writeText(x.url);
   setStatus('链接已复制，正在打开下载页。进入后直接粘贴即可。','good')
 }catch(e){
   setStatus('正在打开下载页。进入后粘贴当前 Instagram 链接。','good')
 }
 remember(x);
 window.open(COBALT_URL,'_blank','noopener')
}
function openOriginal(){
 const x=current();if(!x.url){setStatus('请先粘贴有效链接。','bad');return}
 window.open(x.url,'_blank','noopener')
}
function sendToJob(){
 const x=current();if(!x.url){setStatus('请先粘贴有效链接。','bad');return}
 S().videoJobs=S().videoJobs||[];
 const title=x.title||'Instagram 视频 · AI剪辑任务';
 S().videoJobs.unshift({
   id:uid('job'),title,type:'hot15',typeLabel:'15秒热点版',duration:15,status:'WAITING_FOR_SOURCE',createdAt:Date.now(),
   source:'instagram',brief:'先通过下载页获取授权素材，再导入 VideoHighlighter / Cutpoint；前1秒优先最强镜头，输出9:16。',
   requiredTags:['highlight','goal','save','celebration','crowd'],
   sourcePayload:{download:{url:x.url,title}},revisions:[],resultUrl:'',approvedAt:0
 });
 save();remember(x);note('已送入 AI VIDEO JOB');C.switchView('videojobs')
}
function remove(id){
 S().downloadItems=(S().downloadItems||[]).filter(x=>x.id!==id);save();renderHistory()
}
function useHistory(id,action){
 const x=(S().downloadItems||[]).find(a=>a.id===id);if(!x)return;
 if(q('downloadUrl'))q('downloadUrl').value=x.url;
 if(q('downloadTitle'))q('downloadTitle').value=x.title||'';
 if(action==='download')download()
}
function renderHistory(){
 const host=q('downloadHistory');if(!host)return;
 const list=S().downloadItems||[];
 host.innerHTML=list.length?list.map(x=>'<div class="downloadHistoryRow"><div><b>'+esc(x.title||'Instagram 视频')+'</b><span>'+esc(x.url)+'</span></div><div class="downloadHistoryActions"><button class="btn blue" data-dl-again="'+x.id+'" type="button">再下载</button><button class="btn danger" data-dl-del="'+x.id+'" type="button">删除</button></div></div>').join(''):'<div class="empty">还没有下载记录。</div>';
 host.querySelectorAll('[data-dl-again]').forEach(b=>b.onclick=()=>useHistory(b.dataset.dlAgain,'download'));
 host.querySelectorAll('[data-dl-del]').forEach(b=>b.onclick=()=>remove(b.dataset.dlDel))
}
function render(){renderHistory()}
if(q('downloadStartBtn'))q('downloadStartBtn').onclick=download;
if(q('downloadOpenBtn'))q('downloadOpenBtn').onclick=openOriginal;
if(q('downloadToJobBtn'))q('downloadToJobBtn').onclick=sendToJob;
if(q('downloadUrl'))q('downloadUrl').addEventListener('keydown',e=>{if(e.key==='Enter')download()});
window.SAGI_DOWNLOADER={render,download,sendToJob};
render();
})();