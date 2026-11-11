const CACHE='sagi-ai-local-v133';
const SHELL=['./manifest.webmanifest'];
self.addEventListener('install',e=>e.waitUntil((async()=>{const c=await caches.open(CACHE);await c.addAll(SHELL);await self.skipWaiting()})()));
self.addEventListener('activate',e=>e.waitUntil((async()=>{const keys=await caches.keys();await Promise.all(keys.filter(k=>k!==CACHE).map(k=>caches.delete(k)));await self.clients.claim()})()));
self.addEventListener('fetch',e=>{
  const req=e.request;
  if(req.method!=='GET')return;
  const url=new URL(req.url);
  const isPage=req.mode==='navigate'||url.pathname.endsWith('/sagi-local/')||url.pathname.endsWith('/sagi-local/index.html');
  if(isPage){
    e.respondWith((async()=>{try{const fresh=await fetch(req,{cache:'no-store'});const c=await caches.open(CACHE);c.put('./index.html',fresh.clone()).catch(()=>{});return fresh}catch{return (await caches.match('./index.html'))||Response.error()}})());
    return;
  }
  e.respondWith((async()=>{const cached=await caches.match(req);if(cached)return cached;const fresh=await fetch(req);const c=await caches.open(CACHE);c.put(req,fresh.clone()).catch(()=>{});return fresh})());
});