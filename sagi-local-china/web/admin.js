(function(){
const $=s=>document.querySelector(s);
const KEY='sagiLocalAdminKey';
function key(){return sessionStorage.getItem(KEY)||''}
function msg(t,type){const e=$('#adminMessage');e.textContent=t||'';e.className='message'+(type?' '+type:'')}
async function req(path,opt){
  const o=Object.assign({},opt||{});
  o.headers=Object.assign({'X-Admin-Key':key()},o.headers||{});
  const r=await fetch(path,o);
  let d={};try{d=await r.json()}catch{}
  if(!r.ok)throw new Error(d.detail||('HTTP '+r.status));
  return d;
}
function bytes(n){
  n=Number(n)||0;
  if(n<1024*1024)return Math.round(n/1024)+' KB';
  if(n<1024*1024*1024)return (n/1024/1024).toFixed(1)+' MB';
  return (n/1024/1024/1024).toFixed(2)+' GB';
}
async function load(){
  const [summary,users]=await Promise.all([req('/api/admin/summary'),req('/api/admin/users')]);
  const s=summary.summary||{};
  $('#statUsers').textContent=s.users||0;
  $('#statProjects').textContent=s.projects||0;
  $('#statAssets').textContent=s.assets||0;
  $('#statStorage').textContent=bytes(s.storage_bytes||0);
  const box=$('#merchantList');box.innerHTML='';
  (users.users||[]).forEach(u=>{
    const row=document.createElement('div');row.className='merchantRow';
    const q=u.quota||{},usage=q.usage||{},rem=q.remaining||{};
    row.innerHTML='<div><b></b><small></small></div><div><b></b><small></small></div><div><select class="field plan"><option value="free">免费版</option><option value="pro">标准版</option><option value="business">商业版</option></select></div><div><small class="quota"></small></div><button class="ghost small save">保存</button>';
    row.children[0].querySelector('b').textContent=u.merchant_name||u.username;
    row.children[0].querySelector('small').textContent=u.username+' · '+(u.industry||'未设置行业');
    row.children[1].querySelector('b').textContent=(u.plan_code||'free').toUpperCase();
    row.children[1].querySelector('small').textContent='状态 '+(u.status||'active');
    const sel=row.querySelector('.plan');sel.value=u.plan_code||'free';
    row.querySelector('.quota').textContent='本月项目 '+(usage.projects||0)+' · AI '+(usage.ai_calls||0)+' · 剩余 '+(rem.projects||0)+' 项目';
    row.querySelector('.save').onclick=async()=>{
      try{
        await req('/api/admin/users/'+u.id+'/plan',{method:'PUT',headers:{'Content-Type':'application/json'},body:JSON.stringify({plan_code:sel.value,status:'active',expires_at:null})});
        msg('已更新 '+(u.merchant_name||u.username)+' 套餐','ok');await load();
      }catch(e){msg(e.message,'error')}
    };
    box.appendChild(row);
  });
}
async function connect(){
  const v=$('#adminKey').value.trim();
  if(v)sessionStorage.setItem(KEY,v);
  try{await load();$('#adminContent').classList.remove('hidden');msg('管理员后台已连接','ok')}
  catch(e){$('#adminContent').classList.add('hidden');msg(e.message,'error')}
}
$('#connectAdmin').onclick=connect;
$('#refreshAdmin').onclick=()=>load().catch(e=>msg(e.message,'error'));
if(key()){ $('#adminKey').value=key(); connect(); }
})();