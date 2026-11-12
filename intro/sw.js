const CACHE_NAME='sagi-live-director-shell-v8';
const CORE=['./','./manifest.webmanifest','./sagi-app-icon.svg'];

self.addEventListener('install',event=>{
  event.waitUntil(caches.open(CACHE_NAME).then(cache=>
    Promise.all(CORE.map(url=>cache.add(url).catch(()=>null)))
  ));
});

self.addEventListener('activate',event=>{
  event.waitUntil(
    caches.keys()
      .then(keys=>Promise.all(keys.filter(k=>k!==CACHE_NAME).map(k=>caches.delete(k))))
      .then(()=>self.clients.claim())
  );
});

self.addEventListener('message',event=>{
  if(event.data&&event.data.type==='SKIP_WAITING')self.skipWaiting();
});

self.addEventListener('fetch',event=>{
  const req=event.request;
  if(req.method!=='GET')return;
  const url=new URL(req.url);
  const sameOrigin=url.origin===self.location.origin;

  if(req.mode==='navigate'){
    event.respondWith(
      fetch(req,{cache:'no-store'})
        .then(res=>{
          const copy=res.clone();
          caches.open(CACHE_NAME).then(cache=>cache.put('./',copy)).catch(()=>{});
          return res;
        })
        .catch(()=>caches.match(req).then(r=>r||caches.match('./')))
    );
    return;
  }

  if(sameOrigin){
    event.respondWith(
      fetch(req,{cache:'no-store'})
        .then(res=>{
          if(res&&res.ok){
            const copy=res.clone();
            caches.open(CACHE_NAME).then(cache=>cache.put(req,copy)).catch(()=>{});
          }
          return res;
        })
        .catch(()=>caches.match(req))
    );
  }
});