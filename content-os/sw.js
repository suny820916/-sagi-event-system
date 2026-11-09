const CACHE='sagi-content-os-shell-v24';
const SHELL=['./','./index.html','./manifest.webmanifest','./icon.svg','./css/mobile.css','./css/mobile.css?v=213','./js/app-core.js','./js/app-core.js?v=213','./js/mobile-matchday.js','./js/video-jobs.js','./js/review.js','./js/mobile-shell.js'];
self.addEventListener('install',e=>{
  self.skipWaiting();
  e.waitUntil(caches.open(CACHE).then(c=>c.addAll(SHELL)).catch(()=>{}));
});
self.addEventListener('activate',e=>{
  e.waitUntil((async()=>{
    const keys=await caches.keys();
    await Promise.all(keys.filter(k=>k.startsWith('sagi-content-os-shell-')&&k!==CACHE).map(k=>caches.delete(k)));
    await self.clients.claim();
  })());
});
self.addEventListener('message',e=>{if(e.data&&e.data.type==='SKIP_WAITING')self.skipWaiting()});
self.addEventListener('fetch',e=>{
  if(e.request.method!=='GET')return;
  const u=new URL(e.request.url);
  if(u.origin!==location.origin)return;
  if(e.request.mode==='navigate'||u.pathname.endsWith('/content-os/')||u.pathname.endsWith('/content-os/index.html')){
    e.respondWith((async()=>{
      try{
        const fresh=await fetch(e.request,{cache:'no-store'});
        const c=await caches.open(CACHE);c.put('./index.html',fresh.clone());return fresh;
      }catch(err){
        return (await caches.match('./index.html'))||(await caches.match('./'))||Response.error();
      }
    })());
    return;
  }
  e.respondWith((async()=>{
    try{return await fetch(e.request,{cache:'no-store'})}
    catch(err){return (await caches.match(e.request))||Response.error()}
  })());
});