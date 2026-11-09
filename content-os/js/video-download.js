(()=>{'use strict';
const C=window.SAGI_CORE;if(!C)return;
const q=C.q,note=C.note,save=C.save,uid=C.uid,esc=C.esc,S=()=>C.state;
const DIRECT_RE=/\.(mp4|mov|webm|m4v|ogg)(?:$|[?#])/i;
const STREAM_RE=/\.(m3u8|mpd)(?:$|[?#])/i;
const PLATFORM_RE=/(youtube\.com|youtu\.be|douyin\.com|iesdouyin\.com|tiktok\.com|bilibili\.com|b23\.tv|instagram\.com|facebook\.com|x\.com|twitter\.com)/i;
let currentStatus='等待粘贴视频链接。';

function normalize(v){
 const s=String(v||'').trim();if(!s)return'';
 try{const u=new URL(s);return /^https?:$/.test(u.protocol)?u.toString():''}catch(e){return''}
}
function platformName(url){
 const h=(()=>{try{return new URL(url).hostname.toLowerCase()}catch(e){return''}})();
 if(/youtu/.test(h))return'YouTube';
 if(/douyin|iesdouyin/.test(h))return'抖音';
 if(/tiktok/.test(h))return'TikTok';
 if(/bilibili|b23/.test(h))return'哔哩哔哩';
 if(/instagram/.test(h))return'Instagram';
 if(/facebook/.test(h))return'Facebook';
 if(/x\.com|twitter/.test(h))return'X / Twitter';
 return'平台页面';
}
function safeName(url,title){
 let base=String(title||'').trim();
 if(!base)try{base=decodeURIComponent(new URL(url).pathname.split('/').pop()||'video')}catch(e){base='video'}
 base=base.replace(/[\\/:*?"<>|]+/g,'_').replace(/\s+/g,' ').trim().slice(0,80)||'video';
 if(!/\.(mp4|mov|webm|m4v|ogg)$/i.test(base)){
   const m=String(url).match(/\.(mp4|mov|webm|m4v|ogg)(?:$|[?#])/i);base+='.'+(m?.[1]||'mp4')
 }
 return base
}
function setStatus(msg,kind=''){
 currentStatus=msg;
 const el=q('downloadStatus');if(el){el.textContent=msg;el.className='downloadStatus '+kind}
}
function current(){
 const url=normalize(q('downloadUrl')?.value),title=(q('downloadTitle')?.value||'').trim();
 return{url,title,direct:DIRECT_RE.test(url),stream:STREAM_RE.test(url),platform:PLATFORM_RE.test(url)}
}
function preview(){
 const x=current(),video=q('downloadPreview');
 if(!x.url){setStatus('链接无效，请粘贴 http / https 视频地址。','bad');return}
 if(x.platform&&!x.direct){
   video.removeAttribute('src');video.load();
   setStatus(platformName(x.url)+' 页面不是视频文件直链。浏览器版不绕过平台限制；可打开原链接，或粘贴你拥有权限的 MP4 / MOV / WEBM 直链。','warn');return
 }
 if(x.stream){
   video.removeAttribute('src');video.load();
   setStatus('检测到 HLS/DASH 流媒体列表。当前版本不在浏览器端拼接分片；请使用授权后的直链文件。','warn');return
 }
 video.src=x.url;video.load();
 setStatus(x.direct?'已识别为视频直链，可以预览和下载。':'已尝试载入链接；如果无法播放，请换成 MP4 / MOV / WEBM 直链。',x.direct?'good':'warn')
}
function remember(x){
 S().downloadItems=S().downloadItems||[];
 S().downloadItems.unshift({id:uid('dl'),url:x.url,title:x.title||safeName(x.url,''),createdAt:Date.now()});
 S().downloadItems=S().downloadItems.slice(0,20);save();renderHistory()
}
function download(){
 const x=current();
 if(!x.url){setStatus('请先粘贴有效视频链接。','bad');return}
 if(!x.direct){
   setStatus((x.platform?platformName(x.url)+' 页面':'当前链接')+'不是可直接下载的视频文件。请使用你有权下载的 MP4 / MOV / WEBM 直链。','warn');return
 }
 const a=document.createElement('a');a.href=x.url;a.download=safeName(x.url,x.title);a.target='_blank';a.rel='noopener';document.body.appendChild(a);a.click();a.remove();
 remember(x);
 setStatus('已发起下载。iPhone 如果打开成播放器，请点“分享”→“存储到文件”。','good');
 note('视频下载已启动')
}
function openOriginal(){
 const x=current();if(!x.url){setStatus('请先粘贴有效链接。','bad');return}
 window.open(x.url,'_blank','noopener')
}
function sendToJob(){
 const x=current();if(!x.url){setStatus('请先粘贴有效视频链接。','bad');return}
 S().videoJobs=S().videoJobs||[];
 const title=x.title||'下载视频 · AI剪辑任务';
 S().videoJobs.unshift({
   id:uid('job'),title,type:'hot15',typeLabel:'15秒热点版',duration:15,status:'WAITING_FOR_BRIDGE',createdAt:Date.now(),
   source:'download',brief:'先获取授权视频源，再进入 VideoHighlighter / Cutpoint；前1秒优先最强镜头，输出9:16。',
   requiredTags:['highlight','goal','save','celebration','crowd'],
   sourcePayload:{download:{url:x.url,title,direct:x.direct,platform:x.platform}},revisions:[],resultUrl:'',approvedAt:0
 });
 save();remember(x);note('已送入 AI VIDEO JOB');C.switchView('videojobs')
}
function remove(id){
 S().downloadItems=(S().downloadItems||[]).filter(x=>x.id!==id);save();renderHistory()
}
function useHistory(id,action){
 const x=(S().downloadItems||[]).find(a=>a.id===id);if(!x)return;
 q('downloadUrl').value=x.url;q('downloadTitle').value=x.title||'';
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
 renderHistory();const s=q('downloadStatus');if(s&&!s.textContent.trim())setStatus(currentStatus)
}
q('downloadPreviewBtn').onclick=preview;
q('downloadStartBtn').onclick=download;
q('downloadOpenBtn').onclick=openOriginal;
q('downloadToJobBtn').onclick=sendToJob;
q('downloadUrl').addEventListener('keydown',e=>{if(e.key==='Enter')preview()});
window.SAGI_DOWNLOADER={render,preview,download,sendToJob};
render();
})();