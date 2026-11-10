const CACHE='sagi-down-mobile-studio-v14';
const SHELL=['./sagi-down.html','./sagi-down-manifest.webmanifest','./sagi-down-icon.svg'];
self.addEventListener('install',e=>e.waitUntil(caches.open(CACHE).then(c=>c.addAll(SHELL)).catch(()=>{})));
self.addEventListener('activate',e=>e.waitUntil((async()=>{const keys=await caches.keys();await Promise.all(keys.filter(k=>k.startsWith('sagi-down-')&&k!==CACHE).map(k=>caches.delete(k)));await self.clients.claim()})()));
self.addEventListener('fetch',e=>{if(e.request.method!=='GET')return;const u=new URL(e.request.url);if(u.origin!==location.origin)return;e.respondWith((async()=>{try{const r=await fetch(e.request,{cache:'no-store'});return r}catch(err){return (await caches.match(e.request))||Response.error()}})())});