'use strict';

const express = require('express');
const multer = require('multer');
const sharp = require('sharp');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const { JsonStore } = require('./lib/store');
const { quote } = require('./lib/pricing');
const { normalizeCode, makeDownloadCode } = require('./lib/download-code');

const app = express();
const PORT = Number(process.env.PORT || 10000);
const DATA_DIR = path.resolve(process.env.DATA_DIR || path.join(__dirname, 'data'));
const ORIGINAL_DIR = path.join(DATA_DIR, 'originals');
const PREVIEW_DIR = path.join(DATA_DIR, 'previews');
const DB_FILE = path.join(DATA_DIR, 'db.json');
const ADMIN_KEY = process.env.ADMIN_KEY || 'change-this-before-event';
const PUBLIC_TITLE = process.env.PUBLIC_TITLE || 'SAGI MATCH PHOTO';
const PHOTOGRAPHER_CODES = String(process.env.PHOTOGRAPHER_CODES || 'PHOTO-1123')
  .split(',').map(x => x.trim()).filter(Boolean);
const ALLOWED_ORIGINS = String(process.env.ALLOWED_ORIGINS || 'https://sagisports.cn,https://www.sagisports.cn,https://suny820916.github.io')
  .split(',').map(x => x.trim()).filter(Boolean);

for (const dir of [DATA_DIR, ORIGINAL_DIR, PREVIEW_DIR]) fs.mkdirSync(dir, { recursive: true });
const store = new JsonStore(DB_FILE);

app.disable('x-powered-by');
app.use(express.json({ limit: '2mb' }));
app.use(express.urlencoded({ extended: true }));
app.use((req,res,next)=>{
  const origin=req.get('origin');
  if(origin && ALLOWED_ORIGINS.includes(origin)){
    res.set('Access-Control-Allow-Origin',origin);
    res.set('Vary','Origin');
    res.set('Access-Control-Allow-Headers','Content-Type, X-SAGI-ADMIN-KEY, X-SAGI-PHOTOGRAPHER-CODE');
    res.set('Access-Control-Allow-Methods','GET,POST,OPTIONS');
  }
  if(req.method==='OPTIONS') return res.sendStatus(204);
  next();
});
app.use(express.static(path.join(__dirname, 'public'), { maxAge: '5m' }));

function id(prefix='id') {
  return prefix + '_' + Date.now().toString(36) + '_' + crypto.randomBytes(4).toString('hex');
}
function admin(req, res, next) {
  const key = req.get('x-sagi-admin-key') || req.query.adminKey;
  if (key !== ADMIN_KEY) return res.status(401).json({ error: '管理员密钥错误' });
  next();
}
function safe(v, max=80) {
  return String(v || '').trim().slice(0, max);
}
function photographer(req, res, next) {
  const code = safe(req.get('x-sagi-photographer-code'), 80);
  if (!code || !PHOTOGRAPHER_CODES.includes(code)) return res.status(401).json({ error:'摄影师上传码无效' });
  req.photographerCode = code;
  next();
}

function photoById(data, photoId) {
  return data.photos.find(p => p.id === photoId);
}
function publicPhoto(p) {
  return {
    id: p.id, eventId: p.eventId, team: p.team, match: p.match,
    jersey: p.jersey, player: p.player, createdAt: p.createdAt,
    previewUrl: '/media/preview/' + p.id
  };
}
function publicOrder(o){
  return {
    id:o.id,
    photoIds:o.photoIds,
    status:o.status,
    product:o.product,
    productName:o.productName,
    amountFen:o.amountFen,
    nickname:o.nickname,
    contact:o.contact,
    createdAt:o.createdAt,
    codeIssuedAt:o.codeIssuedAt || null
  };
}

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { files: 40, fileSize: 24 * 1024 * 1024 }
});

async function makePreview(buffer, target, label) {
  const meta = await sharp(buffer).metadata();
  const width = Math.min(meta.width || 1600, 1600);
  const font = Math.max(28, Math.round(width / 25));
  const wm = Buffer.from(
    '<svg width="' + width + '" height="240">' +
    '<style>.a{fill:white;font-size:' + font + 'px;font-weight:800;font-family:Arial,sans-serif;letter-spacing:4px}.b{fill:white;opacity:.78;font-size:' + Math.round(font*.45) + 'px;font-family:Arial,sans-serif}</style>' +
    '<rect width="100%" height="100%" fill="black" opacity=".18"/>' +
    '<text x="50%" y="105" text-anchor="middle" class="a">SAGI SPORTS · PREVIEW</text>' +
    '<text x="50%" y="155" text-anchor="middle" class="b">' + label.replace(/[<>&"]/g,'') + '</text>' +
    '</svg>'
  );
  await sharp(buffer)
    .rotate()
    .resize({ width, withoutEnlargement: true })
    .composite([{ input: wm, gravity: 'center' }])
    .jpeg({ quality: 80, mozjpeg: true })
    .toFile(target);
}

app.get('/api/health', (req,res) => res.json({ ok:true, service:'SAGI MATCH PHOTO', version:'1.1.0-code' }));
app.get('/api/config', (req,res) => res.json({
  title: PUBLIC_TITLE,
  checkoutMode: 'wechat-offline-download-code',
  prices: { single:5, five:15, personal:29, team:99 }
}));

app.get('/api/events', (req,res) => {
  const data = store.read();
  res.json(data.events.slice().reverse());
});

app.post('/api/admin/events', admin, (req,res) => {
  const name = safe(req.body.name, 100);
  if (!name) return res.status(400).json({ error:'赛事名称不能为空' });
  const event = { id:id('evt'), name, city:safe(req.body.city,60), date:safe(req.body.date,20), createdAt:new Date().toISOString() };
  store.update(d => { d.events.push(event); return d; });
  res.status(201).json(event);
});

app.get('/api/photos', (req,res) => {
  const data = store.read();
  let list = data.photos.slice();
  const eventId = safe(req.query.eventId,100);
  const team = safe(req.query.team,80).toLowerCase();
  const jersey = safe(req.query.jersey,20).toLowerCase();
  const q = safe(req.query.q,80).toLowerCase();
  if (eventId) list = list.filter(p => p.eventId === eventId);
  if (team) list = list.filter(p => (p.team||'').toLowerCase().includes(team));
  if (jersey) list = list.filter(p => (p.jersey||'').toLowerCase() === jersey);
  if (q) list = list.filter(p => [p.team,p.match,p.jersey,p.player].join(' ').toLowerCase().includes(q));
  res.json(list.slice().reverse().map(publicPhoto));
});

async function handlePhotoUpload(req,res){
  try {
    const eventId = safe(req.body.eventId,100);
    if (!eventId) return res.status(400).json({ error:'请选择赛事' });
    if (!req.files?.length) return res.status(400).json({ error:'请选择照片' });
    const data = store.read();
    if (!data.events.some(e => e.id === eventId)) return res.status(404).json({ error:'赛事不存在' });

    const created = [];
    for (const f of req.files) {
      if (!/^image\//.test(f.mimetype)) continue;
      const pid = id('ph');
      const originalPath = path.join(ORIGINAL_DIR, pid + '.jpg');
      const previewPath = path.join(PREVIEW_DIR, pid + '.jpg');
      await sharp(f.buffer).rotate().jpeg({ quality: 96, chromaSubsampling:'4:4:4' }).toFile(originalPath);
      const label = [safe(req.body.team), safe(req.body.jersey)].filter(Boolean).join(' · ');
      await makePreview(f.buffer, previewPath, label);
      created.push({
        id:pid, eventId, team:safe(req.body.team), match:safe(req.body.match,120),
        jersey:safe(req.body.jersey,20), player:safe(req.body.player,80),
        uploadedBy:req.photographerCode ? 'photographer' : 'admin',
        originalPath, previewPath, createdAt:new Date().toISOString()
      });
    }
    store.update(d => { d.photos.push(...created); return d; });
    res.status(201).json({ count:created.length, photos:created.map(publicPhoto) });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error:'照片处理失败，请重试' });
  }
}

app.post('/api/admin/photos', admin, upload.array('photos', 40), handlePhotoUpload);
app.post('/api/photographer/photos', photographer, upload.array('photos', 40), handlePhotoUpload);

app.get('/api/photographer/check', photographer, (req,res)=>{
  res.json({ ok:true, role:'photographer' });
});

app.get('/media/preview/:id', (req,res) => {
  const data = store.read();
  const p = photoById(data, req.params.id);
  if (!p || !fs.existsSync(p.previewPath)) return res.sendStatus(404);
  res.set('Cache-Control','public, max-age=86400');
  res.sendFile(p.previewPath);
});

app.post('/api/orders', (req,res) => {
  const photoIds = Array.from(new Set((req.body.photoIds || []).map(String))).slice(0,200);
  if (!photoIds.length) return res.status(400).json({ error:'至少选择1张照片' });
  const data = store.read();
  const valid = photoIds.filter(x => photoById(data,x));
  if (valid.length !== photoIds.length) return res.status(400).json({ error:'部分照片不存在，请刷新重选' });
  const pricing = quote(valid.length);
  const order = {
    id:id('ord'), photoIds:valid, status:'awaiting_wechat',
    product:pricing.code, productName:pricing.name, amountFen:pricing.priceFen,
    nickname:safe(req.body.nickname,40), contact:safe(req.body.contact,80),
    createdAt:new Date().toISOString(), codeIssuedAt:null, downloadCode:null
  };
  store.update(d => { d.orders.push(order); return d; });
  res.status(201).json(publicOrder(order));
});

app.get('/api/orders/:id', (req,res) => {
  const data = store.read();
  const o = data.orders.find(x => x.id === req.params.id);
  if (!o) return res.sendStatus(404);
  res.json(publicOrder(o));
});

app.get('/api/admin/orders', admin, (req,res) => {
  const data = store.read();
  res.json(data.orders.slice().reverse());
});

app.post('/api/admin/orders/:id/code', admin, (req,res) => {
  let found;
  store.update(d => {
    const o = d.orders.find(x => x.id === req.params.id);
    if (!o) return d;
    if(!o.downloadCode) o.downloadCode=makeDownloadCode(d.orders);
    o.status='code_issued';
    o.codeIssuedAt=o.codeIssuedAt || new Date().toISOString();
    found={...o};
    return d;
  });
  if (!found) return res.sendStatus(404);
  res.json({
    id:found.id,
    status:found.status,
    amountFen:found.amountFen,
    productName:found.productName,
    downloadCode:found.downloadCode,
    codeIssuedAt:found.codeIssuedAt
  });
});

app.post('/api/redeem', (req,res) => {
  const code=normalizeCode(req.body.code);
  if(code.length<8) return res.status(400).json({ error:'请输入正确的下载码' });
  const data=store.read();
  const o=data.orders.find(x => x.status==='code_issued' && normalizeCode(x.downloadCode)===code);
  if(!o) return res.status(404).json({ error:'下载码无效，请核对后重试' });
  res.json({
    orderId:o.id,
    productName:o.productName,
    count:o.photoIds.length,
    photos:o.photoIds.map((pid,i)=>({
      id:pid,
      name:'高清原图 '+(i+1),
      downloadUrl:'/api/download/'+encodeURIComponent(o.downloadCode)+'/'+pid
    }))
  });
});

app.get('/api/download/:code/:photoId', (req,res) => {
  const code=normalizeCode(req.params.code);
  const data=store.read();
  const o=data.orders.find(x => x.status==='code_issued' && normalizeCode(x.downloadCode)===code);
  if(!o || !o.photoIds.includes(req.params.photoId)) {
    return res.status(403).json({ error:'下载码无效或无权下载这张照片' });
  }
  const p=photoById(data,req.params.photoId);
  if(!p || !fs.existsSync(p.originalPath)) return res.sendStatus(404);
  res.set('Cache-Control','private, no-store');
  res.download(p.originalPath,'SAGI_'+p.id+'.jpg');
});

app.post('/api/find-me', upload.single('selfie'), (req,res) => {
  res.status(501).json({ error:'AI找我将在 V1.1 后续版本接入；本次总决赛先使用球队/号码检索。' });
});

app.get('*', (req,res) => res.sendFile(path.join(__dirname,'public','index.html')));

app.listen(PORT, () => console.log('SAGI MATCH PHOTO running on :' + PORT));
