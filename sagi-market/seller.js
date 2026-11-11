(function(){
const $=s=>document.querySelector(s);
const CLOUD='https://sagi-cloud-bridge-suny820916.onrender.com';
let photo='';

function msg(t,type){const e=$('#sellerMessage');e.textContent=t||'';e.className='message'+(type?' '+type:'')}
function download(blob,name){const u=URL.createObjectURL(blob),a=document.createElement('a');a.href=u;a.download=name;document.body.appendChild(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(u),3000)}
async function compress(file){
  const img=await new Promise((res,rej)=>{const u=URL.createObjectURL(file),im=new Image();im.onload=()=>{URL.revokeObjectURL(u);res(im)};im.onerror=()=>{URL.revokeObjectURL(u);rej(new Error('照片读取失败'))};im.src=u});
  const max=720,scale=Math.min(1,max/Math.max(img.naturalWidth,img.naturalHeight));
  const c=document.createElement('canvas');c.width=Math.max(1,Math.round(img.naturalWidth*scale));c.height=Math.max(1,Math.round(img.naturalHeight*scale));c.getContext('2d').drawImage(img,0,0,c.width,c.height);
  let q=.72,data=c.toDataURL('image/jpeg',q);
  while(data.length>560000&&q>.38){q-=.08;data=c.toDataURL('image/jpeg',q)}
  if(data.length>620000)throw new Error('照片仍然太大，请换一张或裁剪后提交');
  return data;
}
function payload(){
  return {
    name:$('#sellerName').value.trim(),
    category:$('#sellerCategory').value,
    seller:$('#sellerSeller').value.trim(),
    contact:$('#sellerContact').value.trim(),
    size:$('#sellerSize').value.trim(),
    condition:$('#sellerCondition').value.trim(),
    city:$('#sellerCity').value.trim(),
    price:Number($('#sellerPrice').value||0),
    notes:$('#sellerNotes').value.trim(),
    photo:photo
  };
}
async function fallbackPack(data,error){
  const id='LOCAL-'+Date.now().toString(36).toUpperCase();
  const pack={version:'1.1',submissionId:id,createdAt:new Date().toISOString(),reason:String(error||'cloud unavailable'),payload:data};
  const file=new File([JSON.stringify(pack)],'SAGI_MARKET_SUBMISSION_'+id+'.json',{type:'application/json'});
  if(navigator.canShare&&navigator.share&&navigator.canShare({files:[file]})){
    try{
      await navigator.share({title:'SAGI MARKET 闲置提交单',text:'云端暂不可用，把这个提交单发给 SAGI 即可审核。',files:[file]});
      msg('提交单已生成。发送给 SAGI 后，不需要重新填写。','ok');
      return;
    }catch(e){}
  }
  download(file,file.name);
  msg('云端暂不可用，已生成提交单文件。把这个文件发给 SAGI 即可，不用重新填写。','error');
}
async function submit(e){
  e.preventDefault();
  if(!$('#sellerAgree').checked)return msg('请先确认商品信息真实','error');
  const data=payload();
  if(!data.name||!data.seller||!data.contact||!data.notes)return msg('请把带 * 的信息填写完整','error');
  const btn=$('#sellerSubmit');btn.disabled=true;btn.textContent='正在提交…';msg('正在发送到 SAGI 收货箱…');
  try{
    const r=await fetch(CLOUD+'/api/market/submit',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)});
    const out=await r.json().catch(()=>({}));
    if(!r.ok||!out.ok)throw new Error(out.error||('HTTP '+r.status));
    $('#sellerForm').classList.add('hidden');$('#successCard').classList.remove('hidden');$('#submissionId').textContent='提交编号：'+out.submissionId;window.scrollTo({top:0,behavior:'smooth'});
  }catch(err){
    await fallbackPack(data,err.message||err);
  }finally{btn.disabled=false;btn.textContent='提交给 SAGI 审核'}
}
$('#sellerPhoto').onchange=async e=>{const f=e.target.files&&e.target.files[0];if(!f)return;msg('正在压缩照片…');try{photo=await compress(f);$('#sellerPhotoPreview').src=photo;$('#sellerPhotoPreview').classList.remove('hidden');$('#sellerPhotoHint').classList.add('hidden');msg('照片已准备好','ok')}catch(err){photo='';msg(err.message,'error')}};
$('#sellerForm').onsubmit=submit;
$('#submitAnother').onclick=()=>{location.reload()};
})();