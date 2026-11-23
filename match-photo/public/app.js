'use strict';

const $ = s => document.querySelector(s);
let photos = [], selected = new Set(), events = [];
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
    renderPhotos();
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
    $('#orderResult').innerHTML=
      '<div class="summary"><b>订单 '+o.id+'</b><br/><span>'+o.productName+' · '+yuan(o.amountFen)+'</span></div>'+
      '<p><b>付款不在本页面完成。</b><br/>请单独微信付款，并把上面的订单号发给 SAGI 工作人员。确认收款后，工作人员会给你一个下载码。</p>'+
      '<p>拿到下载码后，在首页“兑换高清原图”输入即可下载。</p>';
  }catch(e){toast(e.message)}
}
async function redeem(){
  const code=$('#redeemCode').value.trim();
  if(!code) return toast('请输入下载码');
  try{
    const r=await api('/api/redeem',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({code})});
    $('#redeemResult').innerHTML='<div class="summary"><b>'+r.productName+'</b><br/><small>'+r.count+' 张高清原图</small></div><div class="downloads">'+r.photos.map((p,i)=>'<a href="'+p.downloadUrl+'">下载高清原图 '+(i+1)+'</a>').join('')+'</div>';
  }catch(e){ $('#redeemResult').innerHTML=''; toast(e.message); }
}
function adminHeaders(){ return {'x-sagi-admin-key':state.adminKey}; }

$('#searchBtn').onclick=loadPhotos;
$('#clearBtn').onclick=()=>{selected.clear();renderPhotos()};
$('#checkoutBtn').onclick=()=>{ const q=quote(selected.size); $('#checkoutSummary').innerHTML='<b>'+selected.size+' 张照片</b><br/>'+q.name+' · <strong>'+yuan(q.fen)+'</strong>'; $('#orderResult').innerHTML=''; $('#checkoutDialog').showModal(); };
$('#createOrderBtn').onclick=createOrder;
$('#redeemBtn').onclick=redeem;
$('#redeemCode').addEventListener('keydown',e=>{if(e.key==='Enter'){e.preventDefault();redeem()}});
$('#adminBtn').onclick=()=>{ $('#adminKey').value=state.adminKey; $('#adminDialog').showModal(); };
$('#adminKey').onchange=e=>{ state.adminKey=e.target.value.trim(); localStorage.setItem('sagiPhotoAdminKey',state.adminKey); };

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

async function copyText(t){
  try{ await navigator.clipboard.writeText(t); toast('下载码已复制'); }
  catch{ prompt('复制下载码',t); }
}
async function loadOrders(){
  try{
    state.adminKey=$('#adminKey').value.trim(); localStorage.setItem('sagiPhotoAdminKey',state.adminKey);
    const list=await api('/api/admin/orders',{headers:adminHeaders()});
    $('#orders').innerHTML=list.map(o=>{
      const issued=o.status==='code_issued' && o.downloadCode;
      return '<div class="order"><b>'+o.id+'</b><br/><small>'+o.productName+' · '+yuan(o.amountFen)+(o.contact?' · '+o.contact:'')+'</small><br/>'+
        (issued
          ? '<span class="paid">下载码：<b>'+o.downloadCode+'</b></span><button type="button" class="ghost full copyCodeBtn" data-code="'+o.downloadCode+'">复制下载码</button>'
          : '<span class="pending">等待微信收款</span><button type="button" class="primary full issueCodeBtn" data-id="'+o.id+'">已收款 · 生成下载码</button>')+
        '</div>';
    }).join('') || '<small>暂无订单</small>';

    document.querySelectorAll('.issueCodeBtn').forEach(b=>b.onclick=async()=>{
      try{
        const r=await api('/api/admin/orders/'+b.dataset.id+'/code',{method:'POST',headers:adminHeaders()});
        await copyText(r.downloadCode);
        loadOrders();
      }catch(e){toast(e.message)}
    });
    document.querySelectorAll('.copyCodeBtn').forEach(b=>b.onclick=()=>copyText(b.dataset.code));
  }catch(e){toast(e.message)}
}

if('serviceWorker' in navigator) navigator.serviceWorker.register('/sw.js').catch(()=>{});
Promise.all([loadEvents(),loadPhotos()]).catch(e=>toast(e.message));
