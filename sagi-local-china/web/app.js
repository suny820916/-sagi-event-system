(function(){
  const $=function(s){return document.querySelector(s)};
  const $$=function(s){return Array.from(document.querySelectorAll(s))};

  const state={
    authMode:'login',
    profile:{},
    style:'editorial',
    photoFile:null,
    photoImage:null,
    copy:null,
    visual:null,
    generated:false
  };

  function toast(text){
    const el=$('#toast');
    el.textContent=text;
    el.classList.add('show');
    setTimeout(function(){el.classList.remove('show')},1500);
  }

  function message(id,text,type){
    const el=$(id);
    el.textContent=text||'';
    el.className='message'+(type?' '+type:'');
  }

  function showApp(){
    $('#authGate').classList.add('hidden');
    $('#app').classList.remove('hidden');
  }

  function showAuth(){
    $('#app').classList.add('hidden');
    $('#authGate').classList.remove('hidden');
  }

  function setAuthMode(mode){
    state.authMode=mode;
    $('#loginTab').classList.toggle('active',mode==='login');
    $('#registerTab').classList.toggle('active',mode==='register');
    $('#authSubmit').textContent=mode==='login'?'登录':'注册并进入';
    $('#authPass').autocomplete=mode==='login'?'current-password':'new-password';
    message('#authMessage','');
  }

  function setPage(name){
    $$('.page').forEach(function(p){p.classList.remove('active')});
    const page=$('#page'+name);
    if(page)page.classList.add('active');
    $$('.navBtn').forEach(function(btn){
      btn.classList.toggle('active',btn.dataset.page===name);
    });
    window.scrollTo({top:0,behavior:'smooth'});
    if(name==='History')loadHistory();
    if(name==='Account')loadUsage();
  }

  function localCopy(brief){
    const p=state.profile||{};
    const product=(p.product||'真实产品 · 真实场景').trim();
    const headline=(brief||product||'今日推荐').trim().slice(0,18);
    return {
      headline:headline,
      subheadline:(product===headline?'真实产品 · 真实场景':product).slice(0,26),
      cta:'立即了解',
      douyin:headline+'\n\n'+brief+'\n#本地生活',
      moments:brief+'\n\n'+(p.merchant_name||'本店')+'｜欢迎到店 / 私信咨询',
      engine:'local'
    };
  }

  function localVisual(){
    return {
      subject:'真实商家素材',
      scene:'优先保留主体完整和文字空间',
      cropFocus:'center',
      overlayPosition:'bottom',
      engine:'local'
    };
  }

  function currentPack(){
    const copy=state.copy||localCopy($('#brief').value.trim());
    const visual=state.visual||localVisual();
    return {
      headline:copy.headline,
      coverHeadline:copy.headline,
      subheadline:copy.subheadline,
      cta:copy.cta,
      brief:$('#brief').value.trim(),
      cropFocus:visual.cropFocus||'center',
      overlayPosition:visual.overlayPosition||'bottom',
      palette:{text:'#FFFFFF',accent:'#E7C568',shadow:'#000000'}
    };
  }

  function renderPosters(){
    if(!state.photoImage)return;
    const pack=currentPack();
    SAGI_POSTER.render($('#poster34'),state.photoImage,pack,state.style,false,state.profile);
    SAGI_POSTER.render($('#poster916'),state.photoImage,pack,state.style,true,state.profile);
    $('#headline').textContent=pack.headline||'';
    $('#subheadline').textContent=pack.subheadline||'';
    $('#visualSubject').textContent=(state.visual&&state.visual.subject)||'真实商家素材';
    $('#visualScene').textContent=(state.visual&&state.visual.scene)||'优先保留主体完整和文字空间。';
    $('#publishCopy').textContent=(state.copy&&state.copy.moments)||localCopy(pack.brief).moments;
    $('#resultCard').classList.remove('hidden');
    state.generated=true;
  }

  async function normalizePhoto(file){
    const img=await SAGI_POSTER.loadImage(file);
    const max=1600;
    const iw=img.naturalWidth||img.width;
    const ih=img.naturalHeight||img.height;
    const scale=Math.min(1,max/Math.max(iw,ih));
    if(scale===1)return {file:file,image:img};

    const c=document.createElement('canvas');
    c.width=Math.max(1,Math.round(iw*scale));
    c.height=Math.max(1,Math.round(ih*scale));
    c.getContext('2d').drawImage(img,0,0,c.width,c.height);
    const blob=await new Promise(function(resolve){
      c.toBlob(resolve,'image/jpeg',.86);
    });
    if(!blob)return {file:file,image:img};
    const out=new File([blob],'sagi-local-photo.jpg',{type:'image/jpeg'});
    return {file:out,image:await SAGI_POSTER.loadImage(out)};
  }

  async function onPhoto(file){
    if(!file)return;
    try{
      message('#generateMessage','正在读取照片…');
      const normalized=await normalizePhoto(file);
      state.photoFile=normalized.file;
      state.photoImage=normalized.image;
      const url=URL.createObjectURL(normalized.file);
      $('#photoPreview').src=url;
      $('#photoPreview').classList.remove('hidden');
      setTimeout(function(){URL.revokeObjectURL(url)},30000);
      message('#generateMessage','照片已准备好','ok');
    }catch(err){
      state.photoFile=null;
      state.photoImage=null;
      message('#generateMessage',err.message||'照片读取失败','error');
    }
  }

  async function generate(){
    if(!state.photoFile||!state.photoImage){
      message('#generateMessage','先上传一张照片','error');
      return;
    }
    const brief=$('#brief').value.trim()||state.profile.product||'今日推荐';
    $('#brief').value=brief;
    const btn=$('#generateBtn');
    btn.disabled=true;
    btn.textContent='正在生成…';

    state.copy=localCopy(brief);
    state.visual=localVisual();
    $('#engineLabel').textContent='LOCAL POSTER · 已立即生成';
    renderPosters();
    toast('基础海报已生成');

    const copyTask=SAGI_API.aiCopy(brief,state.style).then(function(data){
      if(data&&data.copy)state.copy=data.copy;
      return data;
    }).catch(function(){return null});

    const visionTask=SAGI_API.aiVision(state.photoFile,brief).then(function(data){
      if(data&&data.visual)state.visual=data.visual;
      return data;
    }).catch(function(){return null});

    try{
      const results=await Promise.all([copyTask,visionTask]);
      const copyAI=results[0]&&results[0].copy&&results[0].copy.engine==='ai';
      const visualAI=results[1]&&results[1].visual&&results[1].visual.engine==='ai';
      if(copyAI||visualAI){
        $('#engineLabel').textContent='AI ENHANCED · 国内网关';
        renderPosters();
        toast('AI优化已完成');
      }else{
        $('#engineLabel').textContent='LOCAL POSTER · AI未配置也可正常使用';
      }
    }finally{
      btn.disabled=false;
      btn.textContent='生成海报';
      message('#generateMessage','');
    }
  }

  async function saveProject(){
    if(!state.generated||!state.photoFile){
      toast('先生成海报');
      return;
    }
    const btn=$('#saveProjectBtn');
    btn.disabled=true;
    btn.textContent='保存中…';
    try{
      const poster34=await SAGI_POSTER.canvasToFile($('#poster34'),'SAGI_LOCAL_3x4.png');
      const poster916=await SAGI_POSTER.canvasToFile($('#poster916'),'SAGI_LOCAL_9x16.png');
      const uploaded=await Promise.all([
        SAGI_API.uploadAsset(state.photoFile,'source'),
        SAGI_API.uploadAsset(poster34,'poster34'),
        SAGI_API.uploadAsset(poster916,'poster916')
      ]);
      const project={
        title:(state.copy&&state.copy.headline)||$('#brief').value.trim()||'海报',
        brief:$('#brief').value.trim(),
        style:state.style,
        source_asset_id:uploaded[0].asset.id,
        poster34_asset_id:uploaded[1].asset.id,
        poster916_asset_id:uploaded[2].asset.id,
        metadata:{
          copy:state.copy||{},
          visual:state.visual||{},
          engine:$('#engineLabel').textContent
        }
      };
      await SAGI_API.createProject(project);
      toast('已保存到历史');
    }catch(err){
      toast(err.message||'保存失败');
    }finally{
      btn.disabled=false;
      btn.textContent='保存到历史';
    }
  }

  async function loadProfile(){
    try{
      const data=await SAGI_API.getProfile();
      state.profile=data.profile||{};
      $('#merchantName').value=state.profile.merchant_name||'';
      $('#industry').value=state.profile.industry||'餐饮 / 烧烤';
      $('#product').value=state.profile.product||'';
      $('#audience').value=state.profile.audience||'';
      $('#brandTone').value=state.profile.brand_tone||'';
      $('#phone').value=state.profile.phone||'';
      $('#address').value=state.profile.address||'';
    }catch(err){
      if(err.status===401)logout();
    }
  }

  async function saveProfile(){
    const profile={
      merchant_name:$('#merchantName').value.trim(),
      industry:$('#industry').value,
      product:$('#product').value.trim(),
      audience:$('#audience').value.trim(),
      brand_tone:$('#brandTone').value.trim(),
      phone:$('#phone').value.trim(),
      address:$('#address').value.trim()
    };
    try{
      await SAGI_API.saveProfile(profile);
      state.profile=profile;
      message('#profileMessage','商家档案已保存','ok');
      toast('已保存');
    }catch(err){
      message('#profileMessage',err.message||'保存失败','error');
    }
  }

  function formatTime(ts){
    try{return new Date(Number(ts)*1000).toLocaleString('zh-CN',{month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit'})}
    catch{return ''}
  }

  async function loadHistory(){
    const box=$('#historyList');
    box.innerHTML='<div class="card">正在读取…</div>';
    try{
      const data=await SAGI_API.listProjects();
      const items=data.projects||[];
      if(!items.length){
        box.innerHTML='<div class="card"><div class="sectionTitle">还没有保存过海报</div><div class="message">生成后点“保存到历史”即可。</div></div>';
        return;
      }
      box.innerHTML='';
      items.forEach(function(item){
        const el=document.createElement('div');
        el.className='historyItem';
        const meta=(item.metadata&&item.metadata.engine)||'LOCAL POSTER';
        el.innerHTML='<b></b><p></p><small></small>';
        el.querySelector('b').textContent=item.title||'海报';
        el.querySelector('p').textContent=(item.brief||'')+' · '+String(item.style||'editorial').toUpperCase();
        el.querySelector('small').textContent=formatTime(item.created_at)+' · '+meta;
        box.appendChild(el);
      });
    }catch(err){
      box.innerHTML='<div class="card"><div class="message error">'+(err.message||'读取失败')+'</div></div>';
    }
  }

  function formatBytes(n){
    n=Number(n)||0;
    if(n<1024*1024)return Math.round(n/1024)+' KB';
    if(n<1024*1024*1024)return (n/1024/1024).toFixed(1)+' MB';
    return (n/1024/1024/1024).toFixed(2)+' GB';
  }

  async function loadUsage(){
    const box=$('#usageList');
    box.textContent='读取中…';
    try{
      const results=await Promise.all([SAGI_API.usage(),SAGI_API.quota()]);
      const data=results[0],quotaData=results[1];
      const items=data.usage||[];
      box.innerHTML=items.length?items.map(function(x){
        return '<div>'+String(x.action)+' · '+String(x.engine)+'：'+String(x.count)+' 次</div>';
      }).join(''):'本月暂无AI调用记录';

      const q=quotaData.quota||{},sub=q.subscription||{},rem=q.remaining||{};
      const plan=(sub.limits&&sub.limits.name)||sub.plan_code||'免费版';
      $('#accountPlan').textContent=plan;
      $('#accountProjects').textContent=String(rem.projects??'—');
      $('#accountAICalls').textContent=String(rem.ai_calls??'—');
      $('#accountStorage').textContent=rem.storage_bytes===undefined?'—':formatBytes(rem.storage_bytes);
    }catch(err){
      box.textContent=err.message||'读取失败';
    }
  }

  async function checkHealth(){
    try{
      const h=await SAGI_API.health();
      $('#healthBadge').textContent=h.aiConfigured?'国内服务 · AI已接入':'国内服务 · 基础版可用';
      $('#healthBadge').classList.add('ok');
      $('#accountAI').textContent=h.aiConfigured?'已接入':'未配置 · 不影响基础海报';
    }catch{
      $('#healthBadge').textContent='服务异常';
      $('#accountAI').textContent='服务异常';
    }
  }

  async function doAuth(){
    const username=$('#authUser').value.trim();
    const password=$('#authPass').value;
    if(username.length<3||password.length<6){
      message('#authMessage','账号至少3位，密码至少6位','error');
      return;
    }
    const btn=$('#authSubmit');
    btn.disabled=true;
    btn.textContent=state.authMode==='login'?'登录中…':'注册中…';
    try{
      const data=state.authMode==='login'
        ?await SAGI_API.login(username,password)
        :await SAGI_API.register(username,password);
      SAGI_API.setToken(data.token);
      message('#authMessage','');
      showApp();
      await Promise.all([loadProfile(),checkHealth()]);
    }catch(err){
      message('#authMessage',err.message||'操作失败','error');
    }finally{
      btn.disabled=false;
      btn.textContent=state.authMode==='login'?'登录':'注册并进入';
    }
  }

  function logout(){
    SAGI_API.setToken('');
    state.photoFile=null;state.photoImage=null;state.generated=false;
    showAuth();
  }

  function bind(){
    $('#loginTab').onclick=function(){setAuthMode('login')};
    $('#registerTab').onclick=function(){setAuthMode('register')};
    $('#authSubmit').onclick=doAuth;
    $('#authPass').addEventListener('keydown',function(e){if(e.key==='Enter')doAuth()});

    $('#photoInput').onchange=function(e){onPhoto(e.target.files&&e.target.files[0])};
    $('#generateBtn').onclick=generate;
    $('#saveProjectBtn').onclick=saveProject;
    $('#saveProfileBtn').onclick=saveProfile;
    $('#logoutBtn').onclick=logout;

    $$('.quick').forEach(function(btn){
      btn.onclick=function(){
        const current=$('#brief').value.trim();
        $('#brief').value=current?current+' · '+btn.dataset.fill:btn.dataset.fill;
      };
    });

    $$('.styleBtn').forEach(function(btn){
      btn.onclick=function(){
        state.style=btn.dataset.style||'editorial';
        $$('.styleBtn').forEach(function(x){x.classList.toggle('active',x===btn)});
        if(state.generated)renderPosters();
      };
    });

    $$('.navBtn').forEach(function(btn){
      btn.onclick=function(){setPage(btn.dataset.page)};
    });

    $('#download34').onclick=function(){SAGI_POSTER.download($('#poster34'),'SAGI_LOCAL_3x4.png')};
    $('#download916').onclick=function(){SAGI_POSTER.download($('#poster916'),'SAGI_LOCAL_9x16.png')};
    $('#copyPublish').onclick=async function(){
      const text=$('#publishCopy').textContent||'';
      try{await navigator.clipboard.writeText(text);toast('文案已复制')}
      catch{toast('长按文案复制')}
    };
  }

  async function runSelfTest(){
    if(!new URLSearchParams(location.search).has('selftest'))return;
    document.body.dataset.selftest='running';
    try{
      const c=document.createElement('canvas');
      c.width=720;c.height=1080;
      const x=c.getContext('2d');
      const g=x.createLinearGradient(0,0,720,1080);
      g.addColorStop(0,'#202024');g.addColorStop(1,'#7b6228');
      x.fillStyle=g;x.fillRect(0,0,720,1080);
      x.fillStyle='#e7c568';x.fillRect(130,220,460,560);
      x.fillStyle='#111';x.font='bold 52px sans-serif';x.fillText('SAGI TEST',190,520);
      const blob=await new Promise(function(resolve){c.toBlob(resolve,'image/jpeg',.9)});
      if(!blob)throw new Error('test image failed');
      const file=new File([blob],'selftest.jpg',{type:'image/jpeg'});
      state.photoFile=file;
      state.photoImage=await SAGI_POSTER.loadImage(file);
      state.copy={headline:'周末主推',subheadline:'真实产品 · 真实场景',cta:'立即了解',moments:'测试文案',engine:'local'};
      state.visual=localVisual();
      $('#brief').value='周末主推';
      const signatures=[];
      ['editorial','split','impact'].forEach(function(style){
        state.style=style;
        renderPosters();
        signatures.push($('#poster34').toDataURL('image/png').slice(-220));
      });
      const distinct=new Set(signatures).size===3;
      const ok=$('#poster34').dataset.rendered==='1'&&
        $('#poster916').dataset.rendered==='1'&&distinct;
      document.body.dataset.templateSmoke=distinct?'ok':'fail';
      document.body.dataset.selftest=ok?'ok':'fail';
    }catch(err){
      document.body.dataset.selftest='fail:'+String(err&&err.message||err);
    }
  }

  async function boot(){
    bind();
    setAuthMode('login');
    if('serviceWorker' in navigator){
      window.addEventListener('load',function(){navigator.serviceWorker.register('/sw.js').catch(function(){})});
    }
    await checkHealth();
    if(!SAGI_API.getToken()){
      showAuth();
      return;
    }
    try{
      await SAGI_API.me();
      showApp();
      await loadProfile();
    }catch{
      SAGI_API.setToken('');
      showAuth();
    }
  }

  boot();
  runSelfTest();
})();