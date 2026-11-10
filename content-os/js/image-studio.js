
(()=>{
'use strict';
const core=window.SAGI_CORE;
if(!core)return;
const q=core.q, KEY='sagi_image_studio_v1';
const RATIOS={
 '3:4':{w:1080,h:1440,label:'抖音图文 3:4'},
 '9:16':{w:1080,h:1920,label:'竖屏 9:16'},
 '1:1':{w:1080,h:1080,label:'方图 1:1'},
 '16:9':{w:1920,h:1080,label:'横图 16:9'}
};
const TEMPLATES={
 breaking:{name:'热点重击',kicker:'BREAKING',footer:'SAGI SPORTS · 为身边的足球加油'},
 matchday:{name:'MATCH DAY',kicker:'MATCH DAY',footer:'SAGI SPORTS · FOOTBALL'},
 result:{name:'赛果',kicker:'FULL TIME',footer:'SAGI SPORTS · MATCH RESULT'},
 mvp:{name:'MVP',kicker:'PLAYER OF THE MATCH',footer:'SAGI SPORTS · MVP'},
 jersey:{name:'球衣发布',kicker:'NEW SEASON',footer:'SAGI SPORTS · TEAMWEAR'},
 minimal:{name:'极简',kicker:'SAGI SPORTS',footer:'为身边的足球加油'}
};
const THEMES={
 gold:{accent:'#d7b568',text:'#f4f6f7',muted:'#a9b2b5',overlay:'rgba(3,6,7,.76)'},
 ice:{accent:'#9ed8e8',text:'#f5f8f9',muted:'#a8bac0',overlay:'rgba(4,12,16,.72)'},
 red:{accent:'#ff625d',text:'#ffffff',muted:'#c6b6b5',overlay:'rgba(10,4,5,.74)'},
 clean:{accent:'#f2f3f3',text:'#ffffff',muted:'#c2c8ca',overlay:'rgba(0,0,0,.62)'}
};
let st={
 ratio:'3:4',template:'breaking',theme:'gold',brightness:100,contrast:105,saturation:100,zoom:100,rotate:0,panX:0,panY:0,
 kicker:'BREAKING',headline:'',subheadline:'',footer:'SAGI SPORTS · 为身边的足球加油',caption:'',tags:'#新疆足球 #足球 #SAGI',sourceName:''
};
let img=null,objectUrl='',drag=null,initialized=false;

function clamp(v,a,b){return Math.max(a,Math.min(b,v))}
function escName(v){return String(v||'SAGI').replace(/[\\/:*?"<>|]/g,'_').slice(0,46)}
function loadState(){
 try{const x=JSON.parse(localStorage.getItem(KEY)||'{}');st={...st,...x}}catch(e){}
}
function saveState(){
 try{localStorage.setItem(KEY,JSON.stringify({...st,panX:Number(st.panX)||0,panY:Number(st.panY)||0}))}catch(e){}
}
function canvas(){
 return q('imageCanvas');
}
function setupCanvas(){
 const c=canvas(),r=RATIOS[st.ratio]||RATIOS['3:4'];
 if(c.width!==r.w||c.height!==r.h){c.width=r.w;c.height=r.h}
 q('imageSizeText').textContent=r.w+' × '+r.h+' · PNG';
 q('imageRatioText').textContent=r.label;
}
function wrap(ctx,text,maxWidth,fontSize,maxLines){
 const chars=Array.from(String(text||''));const lines=[];let line='';
 ctx.font='900 '+fontSize+'px -apple-system,BlinkMacSystemFont,"PingFang SC","Microsoft YaHei",sans-serif';
 for(const ch of chars){
   if(ch==='\n'){if(line)lines.push(line);line='';if(lines.length>=maxLines)break;continue}
   const test=line+ch;
   if(line&&ctx.measureText(test).width>maxWidth){lines.push(line);line=ch;if(lines.length>=maxLines)break}else line=test;
 }
 if(line&&lines.length<maxLines)lines.push(line);
 if(lines.length===maxLines&&chars.length>lines.join('').length)lines[maxLines-1]=lines[maxLines-1].replace(/[，。；：、\s]*$/,'')+'…';
 return lines;
}
function fitFont(ctx,text,maxWidth,start,min){
 let size=start;
 while(size>min){ctx.font='900 '+size+'px -apple-system,BlinkMacSystemFont,"PingFang SC","Microsoft YaHei",sans-serif';if(ctx.measureText(text).width<=maxWidth)break;size-=4}
 return size;
}
function drawCoverImage(ctx,w,h){
 if(!img)return false;
 const base=Math.max(w/img.naturalWidth,h/img.naturalHeight),scale=base*(Number(st.zoom)||100)/100;
 const iw=img.naturalWidth*scale,ih=img.naturalHeight*scale,cx=w/2+(Number(st.panX)||0)*w,cy=h/2+(Number(st.panY)||0)*h;
 ctx.save();
 ctx.translate(cx,cy);ctx.rotate((Number(st.rotate)||0)*Math.PI/180);
 ctx.filter='brightness('+(Number(st.brightness)||100)+'%) contrast('+(Number(st.contrast)||100)+'%) saturate('+(Number(st.saturation)||100)+'%)';
 ctx.drawImage(img,-iw/2,-ih/2,iw,ih);ctx.restore();ctx.filter='none';
 return true;
}
function drawEmpty(ctx,w,h,accent){
 const g=ctx.createLinearGradient(0,0,w,h);g.addColorStop(0,'#081014');g.addColorStop(.58,'#0d1417');g.addColorStop(1,'#251d0b');ctx.fillStyle=g;ctx.fillRect(0,0,w,h);
 ctx.save();ctx.globalAlpha=.13;ctx.strokeStyle=accent;ctx.lineWidth=3;
 for(let i=-4;i<12;i++){ctx.beginPath();ctx.moveTo(i*180,-100);ctx.lineTo(i*180+680,h+100);ctx.stroke()}
 ctx.restore();
 ctx.fillStyle='rgba(255,255,255,.12)';ctx.font='700 '+Math.max(24,Math.round(w*.027))+'px -apple-system,"PingFang SC",sans-serif';ctx.textAlign='center';ctx.fillText('导入照片后开始编辑',w/2,h/2);ctx.textAlign='left';
}
function drawOverlay(ctx,w,h,t){
 const g=ctx.createLinearGradient(0,0,0,h);g.addColorStop(0,'rgba(0,0,0,.10)');g.addColorStop(.48,'rgba(0,0,0,.20)');g.addColorStop(1,t.overlay);ctx.fillStyle=g;ctx.fillRect(0,0,w,h);
 const glow=ctx.createRadialGradient(w*.82,h*.16,10,w*.82,h*.16,w*.72);glow.addColorStop(0,t.accent+'44');glow.addColorStop(1,t.accent+'00');ctx.fillStyle=glow;ctx.fillRect(0,0,w,h);
}
function drawBrand(ctx,w,h,t){
 const pad=Math.round(w*.065),small=Math.max(20,Math.round(w*.021));
 ctx.fillStyle=t.accent;ctx.fillRect(pad,Math.round(h*.055),Math.round(w*.12),Math.max(5,Math.round(w*.006)));
 ctx.fillStyle=t.text;ctx.font='900 '+Math.max(25,Math.round(w*.032))+'px -apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif';ctx.fillText('SAGI SPORTS',pad,Math.round(h*.105));
 ctx.fillStyle=t.muted;ctx.font='650 '+small+'px -apple-system,"PingFang SC",sans-serif';ctx.fillText('FOOTBALL CONTENT OS',pad,Math.round(h*.135));
}
function drawDefaultText(ctx,w,h,t){
 const pad=Math.round(w*.065),max=w-pad*2,kicker=String(st.kicker||'').trim(),headline=String(st.headline||'').trim(),sub=String(st.subheadline||'').trim();
 const baseY=Math.round(h*(st.template==='minimal'?.62:.58));
 ctx.fillStyle=t.accent;ctx.font='900 '+Math.max(24,Math.round(w*.034))+'px -apple-system,"PingFang SC",sans-serif';ctx.fillText(kicker.toUpperCase(),pad,baseY);
 const start=Math.round(w*(st.template==='breaking'?.09:.075)),fs=Math.max(52,fitFont(ctx,headline||'你的主标题',max,start,44));
 const lines=wrap(ctx,headline||'你的主标题',max,fs,4),lh=fs*1.12;
 ctx.fillStyle=t.text;ctx.font='900 '+fs+'px -apple-system,BlinkMacSystemFont,"PingFang SC","Microsoft YaHei",sans-serif';
 lines.forEach((line,i)=>ctx.fillText(line,pad,baseY+Math.round(w*.08)+i*lh));
 const subY=baseY+Math.round(w*.08)+lines.length*lh+Math.round(w*.03);
 if(sub){ctx.fillStyle=t.muted;ctx.font='650 '+Math.max(26,Math.round(w*.030))+'px -apple-system,"PingFang SC",sans-serif';wrap(ctx,sub,max,Math.max(26,Math.round(w*.030)),3).forEach((line,i)=>ctx.fillText(line,pad,subY+i*Math.round(w*.043)))}
}
function drawResult(ctx,w,h,t){
 const pad=Math.round(w*.065),max=w-pad*2,kicker=String(st.kicker||'FULL TIME').toUpperCase(),headline=String(st.headline||'3 : 2').trim(),sub=String(st.subheadline||'').trim();
 const score=(headline.match(/\d+\s*[:：-]\s*\d+/)||[])[0];
 ctx.fillStyle=t.accent;ctx.font='900 '+Math.max(26,Math.round(w*.035))+'px -apple-system,"PingFang SC",sans-serif';ctx.fillText(kicker,pad,Math.round(h*.54));
 if(score){
   const before=headline.replace(score,'').trim();
   ctx.fillStyle=t.text;ctx.font='1000 '+Math.max(130,Math.round(w*.19))+'px -apple-system,"PingFang SC",sans-serif';ctx.fillText(score.replace(/-/g,':'),pad,Math.round(h*.70));
   if(before){ctx.fillStyle=t.text;ctx.font='900 '+Math.max(42,Math.round(w*.058))+'px -apple-system,"PingFang SC",sans-serif';wrap(ctx,before,max,Math.max(42,Math.round(w*.058)),2).forEach((line,i)=>ctx.fillText(line,pad,Math.round(h*.78)+i*Math.round(w*.07)))}
 }else drawDefaultText(ctx,w,h,t);
 if(sub){ctx.fillStyle=t.muted;ctx.font='650 '+Math.max(26,Math.round(w*.029))+'px -apple-system,"PingFang SC",sans-serif';wrap(ctx,sub,max,Math.max(26,Math.round(w*.029)),2).forEach((line,i)=>ctx.fillText(line,pad,Math.round(h*.86)+i*Math.round(w*.042)))}
}
function drawMvp(ctx,w,h,t){
 const pad=Math.round(w*.065),max=w-pad*2;
 ctx.save();ctx.globalAlpha=.15;ctx.fillStyle=t.accent;ctx.font='1000 '+Math.round(w*.34)+'px -apple-system,sans-serif';ctx.fillText('MVP',Math.round(w*.16),Math.round(h*.58));ctx.restore();
 drawDefaultText(ctx,w,h,t);
 ctx.fillStyle=t.accent;ctx.fillRect(pad,Math.round(h*.50),max,Math.max(4,Math.round(w*.005)));
}
function drawJersey(ctx,w,h,t){
 const pad=Math.round(w*.065),max=w-pad*2;
 ctx.save();ctx.globalAlpha=.10;ctx.strokeStyle=t.accent;ctx.lineWidth=Math.max(3,Math.round(w*.004));ctx.strokeRect(pad,Math.round(h*.42),max,Math.round(h*.43));ctx.restore();
 drawDefaultText(ctx,w,h,t);
}
function drawFooter(ctx,w,h,t){
 const pad=Math.round(w*.065),footer=String(st.footer||'').trim();
 ctx.fillStyle='rgba(255,255,255,.13)';ctx.fillRect(pad,h-Math.round(h*.09),w-pad*2,2);
 ctx.fillStyle=t.muted;ctx.font='650 '+Math.max(19,Math.round(w*.021))+'px -apple-system,"PingFang SC",sans-serif';ctx.fillText(footer,pad,h-Math.round(h*.052));
 ctx.textAlign='right';ctx.fillStyle=t.accent;ctx.fillText('SAGI',w-pad,h-Math.round(h*.052));ctx.textAlign='left';
}
function draw(){
 const c=canvas();if(!c)return;setupCanvas();const ctx=c.getContext('2d'),w=c.width,h=c.height,t=THEMES[st.theme]||THEMES.gold;
 ctx.clearRect(0,0,w,h);
 if(!drawCoverImage(ctx,w,h))drawEmpty(ctx,w,h,t.accent);
 drawOverlay(ctx,w,h,t);drawBrand(ctx,w,h,t);
 if(st.template==='result')drawResult(ctx,w,h,t);
 else if(st.template==='mvp')drawMvp(ctx,w,h,t);
 else if(st.template==='jersey')drawJersey(ctx,w,h,t);
 else drawDefaultText(ctx,w,h,t);
 drawFooter(ctx,w,h,t);
}
function syncUi(){
 document.querySelectorAll('[data-image-ratio]').forEach(b=>b.classList.toggle('active',b.dataset.imageRatio===st.ratio));
 document.querySelectorAll('[data-image-template]').forEach(b=>b.classList.toggle('active',b.dataset.imageTemplate===st.template));
 document.querySelectorAll('[data-image-theme]').forEach(b=>b.classList.toggle('active',b.dataset.imageTheme===st.theme));
 const values={imageBrightness:st.brightness,imageContrast:st.contrast,imageSaturation:st.saturation,imageZoom:st.zoom,imageRotate:st.rotate};
 Object.entries(values).forEach(([id,v])=>{if(q(id))q(id).value=v});
 if(q('imageBrightnessVal'))q('imageBrightnessVal').textContent=st.brightness+'%';
 if(q('imageContrastVal'))q('imageContrastVal').textContent=st.contrast+'%';
 if(q('imageSaturationVal'))q('imageSaturationVal').textContent=st.saturation+'%';
 if(q('imageZoomVal'))q('imageZoomVal').textContent=st.zoom+'%';
 if(q('imageRotateVal'))q('imageRotateVal').textContent=st.rotate+'°';
 ['Kicker','Headline','Subheadline','Footer','Caption','Tags'].forEach(k=>{const el=q('image'+k);if(el)el.value=st[k.charAt(0).toLowerCase()+k.slice(1)]||''});
 if(q('imageSourceText'))q('imageSourceText').textContent=st.sourceName||'尚未导入图片';
 setupCanvas();draw();
}
function setTemplate(name){
 if(!TEMPLATES[name])return;st.template=name;const p=TEMPLATES[name];st.kicker=p.kicker;st.footer=p.footer;
 if(name==='matchday'&&!st.headline)st.headline='MATCH DAY';
 if(name==='result'&&!st.headline)st.headline='3 : 2';
 if(name==='mvp'&&!st.headline)st.headline='本场最佳球员';
 if(name==='jersey'&&!st.headline)st.headline='新赛季战袍';
 saveState();syncUi();
}
function bindRange(id,key,suffix){
 const el=q(id);if(!el)return;el.oninput=()=>{st[key]=Number(el.value);const out=q(id+'Val');if(out)out.textContent=st[key]+suffix;saveState();draw()}
}
function bindText(id,key){
 const el=q(id);if(!el)return;el.oninput=()=>{st[key]=el.value;saveState();draw()}
}
function importImage(file){
 if(!file)return;if(objectUrl)URL.revokeObjectURL(objectUrl);objectUrl=URL.createObjectURL(file);
 const next=new Image();next.onload=()=>{img=next;st.sourceName=file.name;st.panX=0;st.panY=0;st.zoom=100;st.rotate=0;saveState();syncUi();core.note('图片已载入 · 可拖动构图')};
 next.onerror=()=>core.note('图片读取失败');next.src=objectUrl;
}
function autoFill(){
 const s=core.state,current=(s.contents||[]).find(x=>x.id===s.currentContentId),d=s.director||{},sel=q('projectSelect'),projectName=(sel?.selectedOptions?.[0]?.textContent||'').replace(/^球队｜/,'').trim();
 const title=(d.cover||d.theme||current?.cover||current?.title||projectName||'').trim();
 const hook=(d.hook||current?.hook||'').trim(),cta=(d.cta||current?.cta||'').trim();
 if(title)st.headline=title;if(hook)st.subheadline=hook;if(cta)st.footer=cta;
 if(current?.tags)st.tags=current.tags;
 if(!st.caption&&title)st.caption=title+(hook?'\n\n'+hook:'')+'\n\n'+st.tags;
 saveState();syncUi();core.note(title?'已从当前内容自动填入':'当前项目还没有可自动填入的标题');
}
function resetAdjust(){
 st.brightness=100;st.contrast=105;st.saturation=100;st.zoom=100;st.rotate=0;st.panX=0;st.panY=0;saveState();syncUi();
}
function canvasBlob(type='image/png',quality=.96){
 return new Promise(resolve=>canvas().toBlob(resolve,type,quality));
}
async function downloadImage(){
 const blob=await canvasBlob('image/png');if(!blob){core.note('导出失败');return}
 const a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download='SAGI_'+escName(st.headline||st.template)+'_'+st.ratio.replace(':','x')+'.png';document.body.appendChild(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(a.href),1200);core.note('高清图片已生成');
}
async function shareImage(){
 const blob=await canvasBlob('image/png');if(!blob){core.note('图片生成失败');return}
 const file=new File([blob],'SAGI_'+escName(st.headline||'POST')+'.png',{type:'image/png'}),text=(st.caption||st.headline||'')+(st.tags?'\n\n'+st.tags:'');
 try{
   if(navigator.canShare&&navigator.canShare({files:[file]})){await navigator.share({files:[file],text});return}
 }catch(e){if(e?.name==='AbortError')return}
 await downloadImage();copyCaption();core.note('当前浏览器不支持图片分享 · 已导出并复制文案');
}
function copyCaption(){
 const text=(st.caption||st.headline||'')+(st.tags?'\n\n'+st.tags:'');if(!text){core.note('先填写发布文案');return}
 navigator.clipboard?.writeText(text).then(()=>core.note('发布文案已复制')).catch(()=>core.note('复制失败'));
}
function toPublish(){
 const s=core.state,pid=s.currentProjectId;
 if(!pid){core.note('先在顶部选择一个内容项目');return}
 const title=(st.headline||'SAGI 图片内容').trim(),now=Date.now();
 let c=(s.contents||[]).find(x=>x.id===s.currentContentId);
 if(!c){
   c={id:core.uid('content'),projectId:pid,createdAt:now};
   s.contents.unshift(c);s.currentContentId=c.id;
 }
 Object.assign(c,{projectId:pid,title,format:'poster',goal:c.goal||'reach',style:'premium',platform:'douyin',hook:st.subheadline||title,cover:title,cta:st.footer||'',tags:st.tags||'',caption:st.caption||'',status:'ready',scheduleAt:c.scheduleAt||(core.today()+'T20:00'),updatedAt:now,imageDraft:{ratio:st.ratio,template:st.template,theme:st.theme,sourceName:st.sourceName,createdAt:now}});
 core.save();core.renderAll();core.note('图片内容已进入发布中心');core.switchView('publish');
}
function bindCanvasDrag(){
 const c=canvas();if(!c)return;
 c.onpointerdown=e=>{drag={x:e.clientX,y:e.clientY,px:Number(st.panX)||0,py:Number(st.panY)||0};c.setPointerCapture?.(e.pointerId)};
 c.onpointermove=e=>{if(!drag||!img)return;const r=c.getBoundingClientRect();st.panX=clamp(drag.px+(e.clientX-drag.x)/Math.max(1,r.width),-.8,.8);st.panY=clamp(drag.py+(e.clientY-drag.y)/Math.max(1,r.height),-.8,.8);draw()};
 const end=()=>{if(drag){drag=null;saveState()}};c.onpointerup=end;c.onpointercancel=end;
}
function bind(){
 if(initialized)return;initialized=true;
 q('imageFile').onchange=e=>{const f=e.target.files?.[0];if(f)importImage(f);e.target.value=''};
 q('imageUploadBtn').onclick=()=>q('imageFile').click();
 q('imageAutoFillBtn').onclick=autoFill;q('imageResetBtn').onclick=resetAdjust;q('imageDownloadBtn').onclick=downloadImage;q('imageShareBtn').onclick=shareImage;q('imageCopyCaptionBtn').onclick=copyCaption;q('imageToPublishBtn').onclick=toPublish;
 document.querySelectorAll('[data-image-template]').forEach(b=>b.onclick=()=>setTemplate(b.dataset.imageTemplate));
 document.querySelectorAll('[data-image-ratio]').forEach(b=>b.onclick=()=>{st.ratio=b.dataset.imageRatio;saveState();syncUi()});
 document.querySelectorAll('[data-image-theme]').forEach(b=>b.onclick=()=>{st.theme=b.dataset.imageTheme;saveState();syncUi()});
 bindRange('imageBrightness','brightness','%');bindRange('imageContrast','contrast','%');bindRange('imageSaturation','saturation','%');bindRange('imageZoom','zoom','%');bindRange('imageRotate','rotate','°');
 bindText('imageKicker','kicker');bindText('imageHeadline','headline');bindText('imageSubheadline','subheadline');bindText('imageFooter','footer');bindText('imageCaption','caption');bindText('imageTags','tags');bindCanvasDrag();
}
function render(){bind();syncUi()}
loadState();
window.SAGI_IMAGE={render,download:downloadImage,share:shareImage,autoFill};
setTimeout(render,0);
})();
