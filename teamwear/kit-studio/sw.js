const CACHE='sagi-kit-v1-china-20261120-rc2-hotfix7';
const CORE=['./start.html','./index.html','./catalog.html','./quote.html','./order-history.html','./production-center.html','./delivery-center.html','./brand-mark.svg','./catalog-data.js','./cloud-sync.js'];
const OPTIONAL=['./','./admin-import.html','./sync-settings.html','./assets.js','./sprite.js','./manifest.webmanifest','./brand-standard.html','./profit-center.html','./commercial-check.html','./release.json','./stable-qa.html','./stable-promotion.html'];
async function cacheOne(cache,url){
  try{
    const r=await fetch(url,{cache:'reload'});
    if(!r||!r.ok)throw new Error('HTTP '+(r&&r.status));
    await cache.put(url,r.clone());
    return true;
  }catch(e){
    console.warn('[SAGI KIT] cache skip',url,e);
    return false;
  }
}
self.addEventListener('install',e=>e.waitUntil((async()=>{
  const c=await caches.open(CACHE);
  const coreResults=await Promise.all(CORE.map(u=>cacheOne(c,u)));
  if(!coreResults.every(Boolean))throw new Error('SAGI KIT core offline cache incomplete');
  await Promise.all(OPTIONAL.map(u=>cacheOne(c,u)));
  await self.skipWaiting();
})()));
self.addEventListener('activate',e=>e.waitUntil((async()=>{
  const keys=await caches.keys();
  await Promise.all(keys.filter(k=>k!==CACHE).map(k=>caches.delete(k)));
  await self.clients.claim();
})()));
self.addEventListener('fetch',e=>{
  if(e.request.method!=='GET')return;
  const isNav=e.request.mode==='navigate';
  e.respondWith((async()=>{
    const hit=await caches.match(e.request,{ignoreSearch:isNav});
    if(hit)return hit;
    try{
      const r=await fetch(e.request);
      if(r&&r.ok){
        const c=await caches.open(CACHE);
        c.put(e.request,r.clone()).catch(()=>{});
      }
      return r;
    }catch(err){
      if(isNav){
        return (await caches.match('./start.html')) || new Response('SAGI KIT offline cache unavailable',{status:503,headers:{'Content-Type':'text/plain;charset=utf-8'}});
      }
      throw err;
    }
  })());
});