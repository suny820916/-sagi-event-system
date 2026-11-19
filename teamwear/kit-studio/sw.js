const CACHE='sagi-kit-v1-china-20261120-rc2-hotfix4';
const ASSETS=['./','./index.html','./start.html','./admin-import.html','./sync-settings.html','./order-history.html','./assets.js','./sprite.js','./cloud-sync.js','./manifest.webmanifest','./brand-mark.svg','./brand-standard.html','./catalog.html','./catalog-data.js','./quote.html','./profit-center.html','./production-center.html','./delivery-center.html','./commercial-check.html','./release.json','./stable-qa.html','./stable-promotion.html'];
self.addEventListener('install',e=>e.waitUntil(caches.open(CACHE).then(c=>c.addAll(ASSETS)).then(()=>self.skipWaiting())));
self.addEventListener('activate',e=>e.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim())));
self.addEventListener('fetch',e=>{if(e.request.method!=='GET')return;
 const isNav=e.request.mode==='navigate';
 e.respondWith(caches.match(e.request).then(hit=>hit||fetch(e.request).then(r=>{if(r&&r.ok){const copy=r.clone();caches.open(CACHE).then(c=>c.put(e.request,copy))}return r}).catch(()=>isNav?caches.match('./start.html'):Promise.reject(new Error('offline asset unavailable')))));
});