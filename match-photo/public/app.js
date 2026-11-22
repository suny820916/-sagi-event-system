'use strict';

const $ = s => document.querySelector(s);
let photos = [], selected = new Set(), events = [], lastOrder = null;
const state = { adminKey: localStorage.getItem('sagiPhotoAdminKey') || '' };

function toast(msg){ const el=$('#toast'); el.textContent=msg; el.style.display='block'; setTimeout(()=>el.style.display='none',2200); }
async function api(url, opts={}){
  const res = await fetch(url, opts);
  const data = await res.json().catch(()=>({}));
  if(!res.ok) throw new Error(data.error || '请求失败');
  return data;
}
function yuan(fen){ return '¥' + (fen/100).toFixed(fen%100?2:0); }
function quote(n){
  if(n<1) return {name:'',fen:0};
  if(n===1) return {name:'单张高清原图',fen:500};
  if(n===2) return {name:'2张高清原图',fen:1000};
  if(n<=5) return {name:'5张精选',fen:1500};
  if(n<=20) return {name:'个人整场精选包',fen:2900};
  return {name:'全队整场照片包',fen:9900};
}
async function loadEvents(){
  events = await api('/api/events');
  const options = events.map(e=>'<option value="'+e.id+'">'+e.name+(e.date?' · '+e.date:'')+'</option>').join('');
  $('#eventSelect').innerHTML='<option value="">全部赛事</option>'+options;
  $('#adminEventSelect').innerHTML='<option value="">选择赛事</option>'+options;
}
async function loadPhotos(){
  const qs=new URLSearchParams();
  if($('#eventSelect').value) qs.set('eventId',$('#eventSelect').value);
  if($('#teamInput').value.trim()) qs.set('team',$('#teamInput').value.trim());
  if($('#jerseyInput').value.trim()) qs.set('jersey',$('#jerseyInput').value.trim());
  photos=await api('/api/photos?'+qs.toString());
  renderPhotos();
}
function renderPhotos(){
  $('#count').textContent=photos.length+' 张';
  $('#empty').style.display=photos.length?'none':'block';
  $('#gallery').innerHTML=photos.map(p=>{
    const on=selected.has(p.id)?' selected':'';
    const info=[p.team,p.jersey?'#'+p.jersey:'',p.player].filter(Boolean).join(' · ');
    return '<article class="photo'+on+'" data-id="'+p.id+'"><img loading="lazy" src="'+p.previewUrl+'" alt="比赛照片"/><span class="check">'+(on?'✓':'')+'</span><div class="meta">'+(info||p.match||'SAGI MATCH PHOTO')+'</div></article>';
  }).join('');
  document.querySelectorAll('.photo').forEach(el=>el.onclick=()=>{
    const id=el.dataset.id;
    selected.has(id)?selected.delete(id):selected.add(id);
    renderPhotos(); updateCart();
  });
  updateCart();
}
function updateCart(){
  const n=selected.size, q=quote(n);
  $('#cart').classList.toggle('hidden',!n);
  $('#selectedCount').textContent=n;
  $('#quoteText').textContent=q.name+' · '+yuan(q.fen);
}
async function createOrder(){
  const ids=[...selected];
  if(!ids.length) return;
  try{
    const o=await api('/api/orders',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({
      photoIds:ids,nickname:$('#nickname').value,contact:$('#contact').value
    })});
    lastOrder=o; renderOrder(o);
  }catch(e){toast(e.message)}
}
async function renderOrder(o){
  const cfg=await api('/api/config');
  let html='<div class="summary"><b>订单 '+o.id+'</b><br/><span>'+o.productName+' · '+yuan(o.amountFen)+'</span><br/><small>状态：'+(o.status==='paid'?'已付款':'等待付款确认')+'</small></div>';
  if(o.status!=='paid'){
    if(cfg.paymentQrUrl) html+='<img class="qr" src="'+cfg.paymentQrUrl+'" alt="微信收款码"/>';
    html+='<p>微信付款后，把订单号出示给 SAGI 工作人员。工作人员确认收款后，本页即可下载无水印原图。</p><button type="button" id="checkPaidBtn" class="ghost full">我已付款，检查状态</button>';
  }else{
    html+='<div class="downloads">'+o.photoIds.map((pid,i)=>'<a href="/api/download/'+o.id+'/'+o.downloadToken+'/'+pid+'">下载高清原图 '+(i+1)+'</a>').join('')+'</div>';
  }
  $('#orderResult').innerHTML=html;
  $('#checkPaidBtn')?.addEventListener('click',async()=>{ try{const fresh=await api('/api/orders/'+o.id); lastOrder=fresh; renderOrder(fresh);}catch(e){toast(e.message)} });
}
function adminHeaders(){ return {'x-sagi-admin-key':state.adminKey}; }

$('#searchBtn').onclick=loadPhotos;
$('#clearBtn').onclick=()=>{selected.clear();renderPhotos()};
$('#checkoutBtn').onclick=()=>{ const q=quote(selected.size); $('#checkoutSummary').innerHTML='<b>'+selected.size+' 张照片</b><br/>'+q.name+' · <strong>'+yuan(q.fen)+'</strong>'; $('#orderResult').innerHTML=''; $('#checkoutDialog').showModal(); };
$('#createOrderBtn').onclick=createOrder;
$('#adminBtn').onclick=()=>{ $('#adminKey').value=state.adminKey; $('#adminDialog').showModal(); };
$('#adminKey').onchange=e=>{ state.adminKey=e.target.value.trim(); localStorage.setItem('sagiPhotoAdminKey',state.adminKey); };
$('#selfieInput').onchange=async e=>{
  if(!e.target.files[0]) return;
  const fd=new FormData(); fd.append('selfie',e.target.files[0]);
  try{await api('/api/find-me',{method:'POST',body:fd})}catch(err){toast(err.message)}
};

$('#createEventBtn').onclick=async()=>{
  try{
    state.adminKey=$('#adminKey').value.trim(); localStorage.setItem('sagiPhotoAdminKey',state.adminKey);
    await api('/api/admin/events',{method:'POST',headers:{...adminHeaders(),'Content-Type':'application/json'},body:JSON.stringify({
      name:$('#eventName').value,city:$('#eventCity').value,date:$('#eventDate').value
    })});
    toast('赛事已创建'); $('#eventName').value=''; await loadEvents();
  }catch(e){toast(e.message)}
};
$('#uploadBtn').onclick=async()=>{
  const fs=$('#photoFiles').files;
  if(!fs.length) return toast('请选择比赛照片');
  const fd=new FormData();
  fd.append('eventId',$('#adminEventSelect').value);
  fd.append('team',$('#uploadTeam').value);
  fd.append('match',$('#uploadMatch').value);
  fd.append('jersey',$('#uploadJersey').value);
  fd.append('player',$('#uploadPlayer').value);
  [...fs].forEach(f=>fd.append('photos',f));
  $('#uploadProgress').value=18;
  try{
    state.adminKey=$('#adminKey').value.trim(); localStorage.setItem('sagiPhotoAdminKey',state.adminKey);
    const r=await api('/api/admin/photos',{method:'POST',headers:adminHeaders(),body:fd});
    $('#uploadProgress').value=100; toast('已上传 '+r.count+' 张并生成水印'); $('#photoFiles').value=''; await loadPhotos();
  }catch(e){ $('#uploadProgress').value=0; toast(e.message); }
};
$('#refreshOrdersBtn').onclick=loadOrders;
async function loadOrders(){
  try{
    state.adminKey=$('#adminKey').value.trim(); localStorage.setItem('sagiPhotoAdminKey',state.adminKey);
    const list=await api('/api/admin/orders',{headers:adminHeaders()});
    $('#orders').innerHTML=list.map(o=>'<div class="order"><b>'+o.id+'</b><br/><small>'+o.productName+' · '+yuan(o.amountFen)+'</small><br/><span class="'+o.status+'">'+(o.status==='paid'?'已付款':'待确认')+'</span>'+(o.status==='pending'?'<button type="button" class="primary full paidBtn" data-id="'+o.id+'">确认已收款</button>':'')+'</div>').join('') || '<small>暂无订单</small>';
    document.querySelectorAll('.paidBtn').forEach(b=>b.onclick=async()=>{try{await api('/api/admin/orders/'+b.dataset.id+'/paid',{method:'POST',headers:adminHeaders()});toast('订单已解锁');loadOrders()}catch(e){toast(e.message)}});
  }catch(e){toast(e.message)}
}

if('serviceWorker' in navigator) navigator.serviceWorker.register('/sw.js').catch(()=>{});
Promise.all([loadEvents(),loadPhotos()]).catch(e=>toast(e.message));
