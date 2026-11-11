(function(){
  const KEY='sagiLocalChinaToken';

  function getToken(){ return localStorage.getItem(KEY)||''; }
  function setToken(v){ if(v)localStorage.setItem(KEY,v); else localStorage.removeItem(KEY); }
  function authHeaders(extra){
    const h=Object.assign({},extra||{});
    const t=getToken();
    if(t)h.Authorization='Bearer '+t;
    return h;
  }
  async function request(path,options){
    const opts=Object.assign({},options||{});
    opts.headers=authHeaders(opts.headers||{});
    const r=await fetch(path,opts);
    let data={};
    try{data=await r.json()}catch{}
    if(!r.ok){
      const err=new Error(data.detail||data.error||('HTTP '+r.status));
      err.status=r.status;
      err.data=data;
      throw err;
    }
    return data;
  }
  async function json(path,method,body){
    return request(path,{
      method:method||'GET',
      headers:{'Content-Type':'application/json'},
      body:body===undefined?undefined:JSON.stringify(body)
    });
  }
  async function form(path,formData){
    return request(path,{method:'POST',body:formData});
  }

  window.SAGI_API={
    getToken,
    setToken,
    health:()=>request('/health'),
    register:(username,password)=>json('/api/auth/register','POST',{username,password}),
    login:(username,password)=>json('/api/auth/login','POST',{username,password}),
    me:()=>request('/api/me'),
    getProfile:()=>request('/api/profile'),
    saveProfile:(profile)=>json('/api/profile','PUT',profile),
    aiCopy:(brief,style)=>json('/api/ai/copy','POST',{brief,style}),
    aiVision:(file,brief)=>{
      const fd=new FormData();
      fd.append('image',file,file.name||'photo.jpg');
      fd.append('brief',brief||'');
      return form('/api/ai/vision',fd);
    },
    uploadAsset:(file,kind)=>{
      const fd=new FormData();
      fd.append('file',file,file.name||'asset.png');
      fd.append('kind',kind||'source');
      return form('/api/assets',fd);
    },
    createProject:(project)=>json('/api/projects','POST',project),
    listProjects:()=>request('/api/projects'),
    usage:()=>request('/api/usage')
  };
})();