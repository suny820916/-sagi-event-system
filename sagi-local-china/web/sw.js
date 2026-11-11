const CACHE='sagi-local-china-v140';
const CORE=['/','/index.html','/styles.css','/api.js','/poster.js','/app.js','/manifest.webmanifest'];
self.addEventListener('install',function(e){
  e.waitUntil(caches.open(CACHE).then(function(c){return c.addAll(CORE)}).then(function(){return self.skipWaiting()}));
});
self.addEventListener('activate',function(e){
  e.waitUntil(caches.keys().then(function(keys){
    return Promise.all(keys.filter(function(k){return k!==CACHE}).map(function(k){return caches.delete(k)}));
  }).then(function(){return self.clients.claim()}));
});
self.addEventListener('fetch',function(e){
  const req=e.request;
  if(req.method!=='GET')return;
  const url=new URL(req.url);
  if(url.pathname.startsWith('/api/')||url.pathname==='/health')return;
  const isPage=req.mode==='navigate'||url.pathname==='/'||url.pathname.endsWith('/index.html');
  if(isPage){
    e.respondWith(fetch(req,{cache:'no-store'}).then(function(r){
      const copy=r.clone();caches.open(CACHE).then(function(c){c.put('/index.html',copy)});return r;
    }).catch(function(){return caches.match('/index.html')}));
    return;
  }
  e.respondWith(caches.match(req).then(function(hit){return hit||fetch(req)}));
});
