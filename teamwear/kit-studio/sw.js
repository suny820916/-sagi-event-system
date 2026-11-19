const CACHE='sagi-kit-v1-china-20261119-logo1';
const ASSETS=['./','./index.html','./start.html','./admin-import.html','./sync-settings.html','./order-history.html','./assets.js','./sprite.js','./cloud-sync.js','./manifest.webmanifest','./brand-mark.svg'];
self.addEventListener('install',e=>e.waitUntil(caches.open(CACHE).then(c=>c.addAll(ASSETS)).then(()=>self.skipWaiting())));
self.addEventListener('activate',e=>e.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim())));
self.addEventListener('fetch',e=>{if(e.request.method!=='GET')return;
 const isNav=e.request.mode==='navigate';
 e.respondWith(caches.match(e.request).then(hit=>hit||fetch(e.request).then(r=>{if(r&&r.ok){const copy=r.clone();caches.open(CACHE).then(c=>c.put(e.request,copy))}return r}).catch(()=>isNav?caches.match('./index.html'):Promise.reject(new Error('offline asset unavailable')))));
});