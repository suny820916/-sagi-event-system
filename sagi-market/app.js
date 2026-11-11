(function(){
const $=s=>document.querySelector(s),$$=s=>Array.from(document.querySelectorAll(s));
const DK='sagiMarketItemsV100',SK='sagiMarketSettingsV100',DB='sagiMarketMedia',STORE='photos';
const CLOUD='https://sagi-cloud-bridge-suny820916.onrender.com',FALLBACK_KEY='sagiMarketFallbackInboxV110';
const defaults={feeLow:10,feeMid:15,feeHigh:10},typeNames={secondhand:'闲置寄售',team_buy:'球队拼团',deal:'限时好价'},prefix={secondhand:'S',team_buy:'T',deal:'D'},statusNames={pending:'待审核',listed:'在售',sold:'已成交',shipped:'已发货',settled:'已结算',cancelled:'已取消'};
let settings=get(SK,defaults),items=get(DK,[]),photoData=null,photoId=null,cloudToken='',cloudInbox=[],fallbackInbox=get(FALLBACK_KEY,[]);
function get(k,d){try{return JSON.parse(localStorage.getItem(k))??d}catch{return d}} function save(){localStorage.setItem(DK,JSON.stringify(items));localStorage.setItem(SK,JSON.stringify(settings));localStorage.setItem(FALLBACK_KEY,JSON.stringify(fallbackInbox))}
function n(v){v=Number(v);return Number.isFinite(v)?v:0} function ts(){return Math.floor(Date.now()/1000)} function money(v){return '¥'+n(v).toFixed(0)} function uid(){return'm'+Date.now().toString(36)+Math.random().toString(36).slice(2,7)}
function toast(t){const e=$('#toast');e.textContent=t;e.classList.add('show');setTimeout(()=>e.classList.remove('show'),1400)}
function db(){return new Promise((res,rej)=>{const r=indexedDB.open(DB,1);r.onupgradeneeded=()=>{if(!r.result.objectStoreNames.contains(STORE))r.result.createObjectStore(STORE)};r.onsuccess=()=>res(r.result);r.onerror=()=>rej(r.error)})}
async function photoPut(id,data){const d=await db();return new Promise((res,rej)=>{const t=d.transaction(STORE,'readwrite');t.objectStore(STORE).put(data,id);t.oncomplete=()=>res();t.onerror=()=>rej(t.error)})}
async function photoGet(id){if(!id)return null;const d=await db();return new Promise((res,rej)=>{const r=d.transaction(STORE).objectStore(STORE).get(id);r.onsuccess=()=>res(r.result||null);r.onerror=()=>rej(r.error)})}
async function photoDel(id){if(!id)return;const d=await db();return new Promise((res,rej)=>{const t=d.transaction(STORE,'readwrite');t.objectStore(STORE).delete(id);t.oncomplete=()=>res();t.onerror=()=>rej(t.error)})}
async function imageData(file){const img=await new Promise((res,rej)=>{const u=URL.createObjectURL(file),im=new Image();im.onload=()=>{URL.revokeObjectURL(u);res(im)};im.onerror=()=>{URL.revokeObjectURL(u);rej(new Error('图片读取失败'))};im.src=u});const max=1000,scale=Math.min(1,max/Math.max(img.naturalWidth,img.naturalHeight)),c=document.createElement('canvas');c.width=Math.max(1,Math.round(img.naturalWidth*scale));c.height=Math.max(1,Math.round(img.naturalHeight*scale));c.getContext('2d').drawImage(img,0,0,c.width,c.height);return c.toDataURL('image/jpeg',.78)}
function nextCode(type){const p=prefix[type]||'X',nums=items.filter(x=>x.type===type).map(x=>parseInt(String(x.code||'').split(p)[1],10)||0);return'SG-'+p+String((nums.length?Math.max.apply(null,nums):0)+1).padStart(3,'0')}
function commission(x){if(x.type==='team_buy')return Math.max(0,(n(x.price)-n(x.unitCost||x.cost))*n(x.joinedQty));const p=n(x.price);if(p<=0)return 0;if(p<100)return Math.min(p,n(settings.feeLow));if(p<300)return p*n(settings.feeMid)/100;return p*n(settings.feeHigh)/100}
function payable(x){return x.type==='team_buy'?0:Math.max(0,n(x.price)-commission(x))} function sold(s){return['sold','shipped','settled'].includes(s)}
function page(name){$('.page').forEach(p=>p.classList.toggle('active',p.id==='page'+name));$('.navBtn').forEach(b=>b.classList.toggle('active',b.dataset.page===name));if(name==='Home'){home();loadInbox();}if(name==='Items')list();if(name==='TeamBuy')teams();if(name==='Finance')finance();window.scrollTo({top:0,behavior:'smooth'})}
async function thumb(host,x){const d=await photoGet(x.photoId).catch(()=>null);if(d){const im=document.createElement('img');im.className='thumb';im.src=d;host.replaceChildren(im)}else{const z=document.createElement('div');z.className='thumb noimg';z.textContent='NO PHOTO';host.replaceChildren(z)}}
function home(){const start=Math.floor(new Date(new Date().getFullYear(),new Date().getMonth(),1).getTime()/1000),month=items.filter(x=>sold(x.status)&&x.updatedAt>=start);$('#kpiActive').textContent=items.filter(x=>x.status==='listed').length;$('#kpiPending').textContent=items.filter(x=>['pending','sold','shipped'].includes(x.status)).length;$('#kpiSold').textContent=month.length;$('#kpiRevenue').textContent=money(month.reduce((a,x)=>a+commission(x),0));const box=$('#todayList');box.innerHTML='';const todo=items.filter(x=>['pending','sold','shipped'].includes(x.status)).sort((a,b)=>b.updatedAt-a.updatedAt).slice(0,6);if(!todo.length){box.innerHTML='<div class="empty">今天没有待处理任务。</div>';return}todo.forEach(x=>{const el=document.createElement('div');el.className='task';const l=document.createElement('div');l.innerHTML='<b></b><small></small>';l.querySelector('b').textContent=x.code+' · '+x.name;l.querySelector('small').textContent=typeNames[x.type]+' · '+(x.status==='pending'?'需要审核上架':x.status==='sold'?'已成交，等待发货':'已发货，等待结算');const b=document.createElement('button');b.className='badge '+x.status;b.textContent=statusNames[x.status];b.onclick=()=>detail(x.id);el.append(l,b);box.append(el)})}
function match(x){const q=$('#searchInput').value.trim().toLowerCase(),t=$('#typeFilter').value,s=$('#statusFilter').value;if(t&&x.type!==t)return false;if(s&&x.status!==s)return false;return!q||[x.code,x.name,x.seller,x.contact,x.city,x.category].join(' ').toLowerCase().includes(q)}
function list(){const box=$('#itemList');box.innerHTML='';const arr=items.filter(match).sort((a,b)=>b.updatedAt-a.updatedAt);if(!arr.length){box.innerHTML='<div class="empty">没有符合条件的商品。</div>';return}arr.forEach(x=>{const card=document.createElement('div');card.className='itemCard';card.onclick=e=>{if(!e.target.closest('button,select,input'))detail(x.id)};const ph=document.createElement('div');thumb(ph,x);const main=document.createElement('div');main.className='itemMain';main.innerHTML='<b></b><small></small><div class="meta"></div>';main.querySelector('b').textContent=x.code+' · '+x.name;main.querySelector('small').textContent=[typeNames[x.type],x.size,x.condition,x.city].filter(Boolean).join(' · ');const badge=document.createElement('span');badge.className='badge '+x.status;badge.textContent=statusNames[x.status];main.querySelector('.meta').append(badge);if(x.type==='team_buy'){const z=document.createElement('span');z.className='badge';z.textContent=n(x.joinedQty)+'/'+n(x.targetQty);main.querySelector('.meta').append(z)}const r=document.createElement('div');r.innerHTML='<div class="price"></div><div class="income"></div>';r.querySelector('.price').textContent=money(x.price);r.querySelector('.income').textContent='SAGI '+money(commission(x));card.append(ph,main,r);box.append(card)})}
function teams(){const box=$('#teamBuyList');box.innerHTML='';const arr=items.filter(x=>x.type==='team_buy'&&x.status!=='cancelled').sort((a,b)=>b.updatedAt-a.updatedAt);if(!arr.length){box.innerHTML='<div class="empty">还没有球队拼团。</div>';return}arr.forEach(x=>{const pct=Math.min(100,Math.round(n(x.joinedQty)/Math.max(1,n(x.targetQty))*100)),el=document.createElement('div');el.className='card';el.innerHTML='<div class="sectionHead"><div><span class="eyebrow"></span><h2></h2></div><div class="price"></div></div><div class="message"></div><div class="progress"><i></i></div><div class="message margin"></div>';el.querySelector('.eyebrow').textContent=x.code+' · TEAM BUY';el.querySelector('h2').textContent=x.name;el.querySelector('.price').textContent=money(x.price)+'/件';el.querySelector('.message').textContent='已拼 '+n(x.joinedQty)+' / 目标 '+n(x.targetQty)+' · '+pct+'%';el.querySelector('.progress i').style.width=pct+'%';el.querySelector('.margin').textContent='预计毛利 '+money(commission(x))+' · 单件毛利 '+money(n(x.price)-n(x.unitCost||x.cost));el.onclick=()=>detail(x.id);box.append(el)})}
function finance(){const arr=items.filter(x=>sold(x.status)),gmv=arr.reduce((a,x)=>a+(x.type==='team_buy'?n(x.price)*n(x.joinedQty):n(x.price)),0),inc=arr.reduce((a,x)=>a+commission(x),0),pay=arr.filter(x=>x.type!=='team_buy'&&x.status!=='settled').reduce((a,x)=>a+payable(x),0),sett=arr.filter(x=>x.type!=='team_buy'&&x.status==='settled').reduce((a,x)=>a+payable(x),0);$('#finGMV').textContent=money(gmv);$('#finIncome').textContent=money(inc);$('#finPayable').textContent=money(pay);$('#finSettled').textContent=money(sett);const box=$('#settleList');box.innerHTML='';const todo=arr.filter(x=>x.type!=='team_buy'&&x.status!=='settled');if(!todo.length){box.innerHTML='<div class="empty">没有待结算订单。</div>';return}todo.forEach(x=>{const e=document.createElement('div');e.className='task';const l=document.createElement('div');l.innerHTML='<b></b><small></small>';l.querySelector('b').textContent=x.code+' · '+x.name;l.querySelector('small').textContent='卖家应得 '+money(payable(x))+' · SAGI '+money(commission(x));const b=document.createElement('button');b.className='primary small';b.textContent='标记已结算';b.onclick=()=>{x.status='settled';x.updatedAt=ts();save();render();toast('已结算')};e.append(l,b);box.append(e)})}
function typeSet(t){$('#businessType').value=t;$$('.seg').forEach(b=>b.classList.toggle('active',b.dataset.type===t));$('#teamBuyFields').classList.toggle('hidden',t!=='team_buy');$('#sellerFields').classList.toggle('hidden',t==='team_buy');$('#costWrap').classList.toggle('hidden',t==='team_buy')}
function reset(t){$('#itemForm').reset();$('#editId').value='';$('#deleteBtn').classList.add('hidden');$('#formTitle').textContent='新增'+typeNames[t];typeSet(t);photoData=null;photoId=null;$('#photoPreview').classList.add('hidden');$('#photoHint').classList.remove('hidden');$('#status').value='pending';$('#targetQty').value='100';$('#joinedQty').value='0'}
function open(t){reset(t||'secondhand');$('#modal').classList.remove('hidden')}
async function edit(id){const x=items.find(i=>i.id===id);if(!x)return;reset(x.type);$('#editId').value=x.id;$('#formTitle').textContent='编辑 '+x.code;$('#deleteBtn').classList.remove('hidden');['name','category','seller','contact','size','condition','city','price','cost','targetQty','joinedQty','unitCost','notes','status'].forEach(k=>{if($('#'+k))$('#'+k).value=x[k]??''});photoId=x.photoId||null;photoData=await photoGet(photoId).catch(()=>null);if(photoData){$('#photoPreview').src=photoData;$('#photoPreview').classList.remove('hidden');$('#photoHint').classList.add('hidden')}$('#detailModal').classList.add('hidden');$('#modal').classList.remove('hidden')}
async function submit(e){e.preventDefault();const id=$('#editId').value||uid(),old=items.find(x=>x.id===id),t=$('#businessType').value;let pid=photoId;if(photoData){pid=pid||('p'+id);await photoPut(pid,photoData)}const x={id:id,code:old?old.code:nextCode(t),type:t,name:$('#name').value.trim(),category:$('#category').value,seller:$('#seller').value.trim(),contact:$('#contact').value.trim(),size:$('#size').value.trim(),condition:$('#condition').value.trim(),city:$('#city').value.trim(),price:n($('#price').value),cost:n($('#cost').value),targetQty:n($('#targetQty').value),joinedQty:n($('#joinedQty').value),unitCost:n($('#unitCost').value),notes:$('#notes').value.trim(),status:$('#status').value,photoId:pid,createdAt:old?old.createdAt:ts(),updatedAt:ts()};if(!x.name){toast('请输入商品名称');return}items=old?items.map(i=>i.id===id?x:i):items.concat(x);save();$('#modal').classList.add('hidden');render();toast(old?'已更新':'已新增 '+x.code)}
async function remove(){const id=$('#editId').value,x=items.find(i=>i.id===id);if(!x||!confirm('确定删除 '+x.code+'？'))return;items=items.filter(i=>i.id!==id);await photoDel(x.photoId).catch(()=>{});save();$('#modal').classList.add('hidden');render();toast('已删除')}
async function detail(id){const x=items.find(i=>i.id===id);if(!x)return;$('#detailCode').textContent=x.code+' · '+x.name;const box=$('#detailBody');box.innerHTML='';const d=await photoGet(x.photoId).catch(()=>null);if(d){const im=document.createElement('img');im.className='detailPhoto';im.src=d;box.append(im)}const p=document.createElement('div');p.className='detailPrice';p.textContent=money(x.price);box.append(p);const meta=document.createElement('div');meta.className='detailMeta';[typeNames[x.type],statusNames[x.status],x.category,x.size,x.condition,x.city].filter(Boolean).forEach(v=>{const z=document.createElement('span');z.textContent=v;meta.append(z)});box.append(meta);const note=document.createElement('div');note.className='detailNotes';note.textContent=(x.notes||'暂无补充说明')+'\n\nSAGI预计收入：'+money(commission(x))+(x.type!=='team_buy'?'\n卖家应得：'+money(payable(x)):'\n拼团进度：'+n(x.joinedQty)+' / '+n(x.targetQty));box.append(note);const acts=document.createElement('div');acts.className='detailActions';const e=document.createElement('button');e.className='ghost';e.textContent='编辑商品';e.onclick=()=>edit(x.id);const c=document.createElement('button');c.className='primary';c.textContent='复制发布文案';c.onclick=()=>copyText(x);const pbtn=document.createElement('button');pbtn.className='ghost';pbtn.textContent='生成商品卡';pbtn.onclick=()=>productCard(x);acts.append(e,c,pbtn);box.append(acts);$('#detailModal').classList.remove('hidden')}
async function productCard(x){
  const c=document.createElement('canvas');c.width=1080;c.height=1350;const ctx=c.getContext('2d');
  ctx.fillStyle='#0b0b0c';ctx.fillRect(0,0,c.width,c.height);
  const d=await photoGet(x.photoId).catch(()=>null);
  if(d){
    const img=await new Promise((res,rej)=>{const im=new Image();im.onload=()=>res(im);im.onerror=rej;im.src=d});
    const boxH=820,scale=Math.max(c.width/img.width,boxH/img.height),sw=c.width/scale,sh=boxH/scale,sx=(img.width-sw)/2,sy=(img.height-sh)/2;
    ctx.drawImage(img,sx,sy,sw,sh,0,0,c.width,boxH);
    const g=ctx.createLinearGradient(0,600,0,900);g.addColorStop(0,'rgba(11,11,12,0)');g.addColorStop(1,'rgba(11,11,12,1)');ctx.fillStyle=g;ctx.fillRect(0,600,c.width,300);
  }else{ctx.fillStyle='#1a1a1d';ctx.fillRect(0,0,c.width,820);ctx.fillStyle='#555';ctx.font='700 42px sans-serif';ctx.textAlign='center';ctx.fillText('SAGI FOOTBALL MARKET',540,410);ctx.textAlign='left'}
  ctx.fillStyle='#e6c568';ctx.font='800 28px sans-serif';ctx.fillText(x.code+' · '+(x.type==='team_buy'?'TEAM BUY':x.type==='deal'?'SAGI DEAL':'SECOND LIFE'),70,865);
  ctx.fillStyle='#fff';ctx.font='900 64px sans-serif';const name=String(x.name||'').slice(0,18);ctx.fillText(name,70,930);
  ctx.fillStyle='#e6c568';ctx.font='950 78px sans-serif';ctx.fillText(money(x.price)+(x.type==='team_buy'?' / 件':''),70,1045);
  ctx.fillStyle='#a0a0a7';ctx.font='500 30px sans-serif';const meta=[x.category,x.size,x.condition,x.city].filter(Boolean).join(' · ');ctx.fillText(meta.slice(0,34),70,1110);
  ctx.fillStyle='#777';ctx.font='500 26px sans-serif';let note=(x.notes||'').replace(/\s+/g,' ').slice(0,42);ctx.fillText(note,70,1165);
  ctx.strokeStyle='#e6c568';ctx.lineWidth=4;ctx.beginPath();ctx.moveTo(70,1230);ctx.lineTo(1010,1230);ctx.stroke();
  ctx.fillStyle='#f5f3ed';ctx.font='900 30px sans-serif';ctx.fillText('SAGI FOOTBALL MARKET',70,1285);
  ctx.fillStyle='#8b8b92';ctx.font='600 24px sans-serif';ctx.textAlign='right';ctx.fillText('萨吉足球闲置与拼团中心',1010,1288);ctx.textAlign='left';
  c.toBlob(blob=>{if(blob)download(blob,x.code+'_'+x.name+'.png')},'image/png');
  toast('商品卡已生成');
}
async function copyText(x){let text;if(x.type==='team_buy')text=x.code+'｜'+x.name+'\n拼团价：'+money(x.price)+'/件\n当前：'+n(x.joinedQty)+'/'+n(x.targetQty)+'\n'+(x.notes||'')+'\n\nSAGI FOOTBALL MARKET｜TEAM BUY';else text=x.code+'｜'+x.name+'\n'+[x.category,x.size,x.condition,x.city].filter(Boolean).join('｜')+'\n售价：'+money(x.price)+'\n'+(x.notes||'')+'\n\nSAGI FOOTBALL MARKET｜'+(x.type==='deal'?'SAGI DEAL':'SECOND LIFE');try{await navigator.clipboard.writeText(text);toast('发布文案已复制')}catch{prompt('复制下面文案',text)}}
async function activateCloud(){
  if(cloudToken)return cloudToken;
  const r=await fetch(CLOUD+'/api/activate',{method:'POST'});
  const d=await r.json().catch(()=>({}));
  if(!r.ok||!d.ok||!d.token)throw new Error(d.error||'云桥激活失败');
  cloudToken=d.token;return cloudToken;
}
async function cloudRequest(path,options){
  const token=await activateCloud(),o=Object.assign({},options||{});
  o.headers=Object.assign({'Authorization':'Bearer '+token},o.headers||{});
  const r=await fetch(CLOUD+path,o),d=await r.json().catch(()=>({}));
  if(!r.ok||!d.ok)throw new Error(d.error||('HTTP '+r.status));
  return d;
}
function sellerUrl(){return location.origin+location.pathname.replace(/index\.html$/,'').replace(/\/?$/,'/')+'seller.html?v=110'}
function submissionCard(sub,source){
  const el=document.createElement('div');el.className='inboxCard';
  const top=document.createElement('div');top.className='inboxTop';
  const info=document.createElement('div');info.innerHTML='<div class="inboxName"></div><div class="inboxMeta"></div>';
  info.querySelector('.inboxName').textContent=sub.name||'未命名闲置';
  info.querySelector('.inboxMeta').textContent=[sub.category,sub.size,sub.condition,sub.city,sub.seller].filter(Boolean).join(' · ')+' · '+money(sub.price);
  const badge=document.createElement('span');badge.className='badge pending';badge.textContent=source==='cloud'?'云端待审核':'离线待审核';top.append(info,badge);el.append(top);
  if(sub.photo){const im=document.createElement('img');im.className='inboxPhoto';im.src=sub.photo;el.append(im)}
  const note=document.createElement('div');note.className='detailNotes';note.textContent=(sub.notes||'暂无说明')+'\n联系方式：'+(sub.contact||'未填写');el.append(note);
  const acts=document.createElement('div');acts.className='inboxActions';
  const reject=document.createElement('button');reject.className='danger';reject.textContent='拒绝';
  const approve=document.createElement('button');approve.className='primary';approve.textContent='通过并上架';
  reject.onclick=()=>rejectSubmission(sub,source);approve.onclick=()=>approveSubmission(sub,source);
  acts.append(reject,approve);el.append(acts);return el;
}
function renderInbox(){
  const box=$('#cloudInboxList');if(!box)return;
  box.innerHTML='';
  const all=cloudInbox.map(x=>({sub:x,source:'cloud'})).concat(fallbackInbox.map(x=>({sub:x.payload||x,source:'offline'})));
  $('#cloudInboxCount').textContent=all.length;
  if(!all.length){box.innerHTML='<div class="empty">暂时没有新的卖家提交。</div>';return}
  all.forEach(x=>box.append(submissionCard(x.sub,x.source)));
}
async function loadInbox(){
  if(!$('#cloudInboxList'))return;
  $('#cloudInboxState').textContent='正在同步云端收货箱…';
  try{
    const d=await cloudRequest('/api/market/inbox');
    cloudInbox=d.items||[];
    $('#cloudInboxState').textContent='云端已同步 · '+cloudInbox.length+' 件待审核';
  }catch(err){
    $('#cloudInboxState').textContent='云端暂不可用 · 仍可导入离线提交单';
  }
  renderInbox();
}
async function approveSubmission(sub,source){
  const sid=sub.id||sub.submissionId||('offline-'+uid());
  let existing=items.find(x=>x.cloudSubmissionId===sid);
  if(!existing){
    const id=uid(),pid=sub.photo?('p'+id):null;
    if(pid&&sub.photo)await photoPut(pid,sub.photo);
    existing={id:id,code:nextCode('secondhand'),type:'secondhand',name:String(sub.name||'').trim()||'未命名闲置',category:sub.category||'其他',seller:sub.seller||'',contact:sub.contact||'',size:sub.size||'',condition:sub.condition||'',city:sub.city||'',price:n(sub.price),cost:0,targetQty:0,joinedQty:0,unitCost:0,notes:sub.notes||'',status:'listed',photoId:pid,cloudSubmissionId:sid,createdAt:ts(),updatedAt:ts()};
    items.push(existing);save();
  }
  if(source==='cloud'){
    try{await cloudRequest('/api/market/decision',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({id:sid,decision:'approved'})})}
    catch(err){toast('已本地上架，云端标记稍后重试');render();return}
  }else{
    fallbackInbox=fallbackInbox.filter(x=>(x.submissionId||(x.payload&&x.payload.id))!==sid);save();
  }
  cloudInbox=cloudInbox.filter(x=>x.id!==sid);render();renderInbox();toast('审核通过 · '+existing.code+' 已上架');
}
async function rejectSubmission(sub,source){
  const sid=sub.id||sub.submissionId;
  if(source==='cloud'){
    try{await cloudRequest('/api/market/decision',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({id:sid,decision:'rejected'})})}
    catch(err){toast('拒绝失败：'+err.message);return}
    cloudInbox=cloudInbox.filter(x=>x.id!==sid);
  }else{
    fallbackInbox=fallbackInbox.filter(x=>(x.submissionId||(x.payload&&x.payload.id))!==sid);save();
  }
  renderInbox();toast('已拒绝，不进入商品库');
}
async function importSellerPack(file){
  const d=JSON.parse(await file.text());
  if(!d.payload||!d.payload.name)throw new Error('不是有效的 SAGI 卖家提交单');
  const sid=d.submissionId||d.payload.id||('LOCAL-'+Date.now().toString(36).toUpperCase());
  d.submissionId=sid;d.payload.id=sid;
  if(!fallbackInbox.some(x=>(x.submissionId||(x.payload&&x.payload.id))===sid))fallbackInbox.push(d);
  save();renderInbox();toast('已进入离线待审核');
}
async function shareSeller(){
  const url=sellerUrl(),data={title:'SAGI 足球闲置寄售',text:'打开链接，提交你的闲置足球装备给 SAGI 审核。',url:url};
  if(navigator.share){try{await navigator.share(data);return}catch{}}
  try{await navigator.clipboard.writeText(url);toast('卖家入口已复制')}catch{prompt('复制卖家入口',url)}
}
function render(){home();list();teams();finance()}
function csv(){const head=['编号','业务','商品','分类','卖家/球队','联系方式','尺码','成色','城市','售价','成本','目标数量','已拼数量','状态','SAGI收入','卖家应得','说明'];const rows=items.map(x=>[x.code,typeNames[x.type],x.name,x.category,x.seller,x.contact,x.size,x.condition,x.city,x.price,x.type==='team_buy'?x.unitCost:x.cost,x.targetQty,x.joinedQty,statusNames[x.status],commission(x),payable(x),x.notes]);const esc=v=>{v=String(v??'');return/[",\n]/.test(v)?'"'+v.replace(/"/g,'""')+'"':v};download(new Blob(['\ufeff'+[head].concat(rows).map(r=>r.map(esc).join(',')).join('\n')],{type:'text/csv;charset=utf-8'}),'SAGI_MARKET.csv')}
function download(blob,name){const u=URL.createObjectURL(blob),a=document.createElement('a');a.href=u;a.download=name;document.body.append(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(u),3000)}
async function backup(){const photos={};for(const x of items)if(x.photoId){const d=await photoGet(x.photoId).catch(()=>null);if(d)photos[x.photoId]=d}download(new Blob([JSON.stringify({version:'1.0.0',settings:settings,items:items,photos:photos})],{type:'application/json'}),'SAGI_MARKET_BACKUP.json')}
async function restore(file){const d=JSON.parse(await file.text());if(!Array.isArray(d.items))throw new Error('备份格式错误');items=d.items;settings=Object.assign({},defaults,d.settings||{});save();for(const k of Object.keys(d.photos||{}))await photoPut(k,d.photos[k]);sync();render();toast('已恢复')}
function sync(){$('#feeLow').value=settings.feeLow;$('#feeMid').value=settings.feeMid;$('#feeHigh').value=settings.feeHigh}
function seed(){if(items.length)return;items=[{id:'demo1',code:'SG-S001',type:'secondhand',name:'Nike Tiempo 传奇',category:'球鞋',seller:'示例卖家',contact:'',size:'42',condition:'9成新',city:'塔城',price:199,cost:0,targetQty:0,joinedQty:0,unitCost:0,notes:'示例数据，可删除。鞋面正常，鞋钉轻微使用痕迹。',status:'listed',photoId:null,createdAt:ts()-86400,updatedAt:ts()-3600},{id:'demo2',code:'SG-T001',type:'team_buy',name:'SAGI 定制比赛服拼团',category:'球队装备',seller:'',contact:'',size:'全码',condition:'全新',city:'新疆',price:69,cost:0,targetQty:100,joinedQty:35,unitCost:40,notes:'满100套开团，支持队徽、号码、姓名。',status:'listed',photoId:null,createdAt:ts()-86400,updatedAt:ts()-1800}];save()}
$$('.navBtn,[data-page]').forEach(b=>b.onclick=()=>page(b.dataset.page));$('#quickAdd').onclick=()=>open('secondhand');$('#addFromItems').onclick=()=>open('secondhand');$$('[data-add-type]').forEach(b=>b.onclick=()=>open(b.dataset.addType));$('#closeModal').onclick=()=>$('#modal').classList.add('hidden');$('#closeDetail').onclick=()=>$('#detailModal').classList.add('hidden');$$('.seg').forEach(b=>b.onclick=()=>typeSet(b.dataset.type));$('#itemForm').onsubmit=submit;$('#deleteBtn').onclick=remove;$('#photoInput').onchange=async e=>{const f=e.target.files&&e.target.files[0];if(!f)return;try{photoData=await imageData(f);$('#photoPreview').src=photoData;$('#photoPreview').classList.remove('hidden');$('#photoHint').classList.add('hidden')}catch(err){toast(err.message)}};['searchInput','typeFilter','statusFilter'].forEach(id=>$('#'+id).addEventListener(id==='searchInput'?'input':'change',list));$('#refreshInbox').onclick=loadInbox;$('#openSellerPage').onclick=()=>window.open(sellerUrl(),'_blank');$('#shareSellerPage').onclick=shareSeller;$('#sellerPackInput').onchange=e=>{const f=e.target.files&&e.target.files[0];if(f)importSellerPack(f).catch(err=>toast(err.message))};$('#exportBtn').onclick=csv;$('#backupJson').onclick=backup;$('#restoreInput').onchange=e=>{const f=e.target.files&&e.target.files[0];if(f)restore(f).catch(err=>toast(err.message))};$('#saveSettings').onclick=()=>{settings={feeLow:n($('#feeLow').value),feeMid:n($('#feeMid').value),feeHigh:n($('#feeHigh').value)};save();render();toast('规则已保存')};$$('.modal').forEach(m=>m.addEventListener('click',e=>{if(e.target===m)m.classList.add('hidden')}));
seed();sync();render();const su=sellerUrl();if($('#sellerQr'))$('#sellerQr').src='https://api.qrserver.com/v1/create-qr-code/?size=220x220&data='+encodeURIComponent(su);loadInbox();if('serviceWorker'in navigator)window.addEventListener('load',()=>navigator.serviceWorker.register('./sw.js').catch(()=>{}));
if(new URLSearchParams(location.search).has('selftest')){try{document.body.dataset.selftest='running';const test={type:'secondhand',price:199};if(Math.round(commission(test))!==30)throw new Error('commission');if(!nextCode('secondhand').startsWith('SG-S'))throw new Error('code');if(items.length<2)throw new Error('seed');document.body.dataset.selftest='ok'}catch(e){document.body.dataset.selftest='fail:'+String(e.message||e)}}
})();