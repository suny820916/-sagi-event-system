const CACHE='sagi-teamwear-shell-v2';
const SHELL=['./','./index.html','./manifest.webmanifest','./sales-icon.svg','./confirmation.html','./receipt.html','./vendor/html2canvas.min.js','./vendor/jspdf.umd.min.js'];
self.addEventListener('install',e=>{
  self.skipWaiting();
  e.waitUntil(caches.open(CACHE).then(c=>c.addAll(SHELL)).catch(()=>{}));
});
self.addEventListener('activate',e=>{
  e.waitUntil((async()=>{
    const keys=await caches.keys();
    await Promise.all(keys.filter(k=>k.startsWith('sagi-teamwear-shell-')&&k!==CACHE).map(k=>caches.delete(k)));
    await self.clients.claim();
  })());
});
self.addEventListener('message',e=>{if(e.data&&e.data.type==='SKIP_WAITING')self.skipWaiting()});
self.addEventListener('fetch',e=>{
  if(e.request.method!=='GET')return;
  const u=new URL(e.request.url);
  if(u.origin!==location.origin)return;
  if(e.request.mode==='navigate'){
    e.respondWith((async()=>{
      try{
        const fresh=await fetch(e.request,{cache:'no-store'});
        const cache=await caches.open(CACHE);
        cache.put(e.request,fresh.clone()).catch(()=>{});
        if(u.pathname.endsWith('/teamwear/')||u.pathname.endsWith('/teamwear/index.html'))cache.put('./index.html',fresh.clone()).catch(()=>{});
        return fresh;
      }catch(err){
        return (await caches.match(e.request))||(u.pathname.endsWith('/teamwear/')?(await caches.match('./index.html')):null)||Response.error();
      }
    })());
    return;
  }
  e.respondWith((async()=>{
    try{
      const fresh=await fetch(e.request,{cache:'no-store'});
      const cache=await caches.open(CACHE);cache.put(e.request,fresh.clone()).catch(()=>{});
      return fresh;
    }catch(err){return (await caches.match(e.request))||Response.error()}
  })());
});