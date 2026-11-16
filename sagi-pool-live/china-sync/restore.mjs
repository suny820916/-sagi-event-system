import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { fileURLToPath } from 'node:url';

const HERE=path.dirname(fileURLToPath(import.meta.url));
const DATA_FILE=process.env.SAGI_DATA_FILE || path.join(HERE,'data.json');
const source=process.argv[2];
if(!source){
  console.error('Usage: node restore.mjs <backup.json|backup.json.gz>');
  process.exit(2);
}
if(!fs.existsSync(source)){
  console.error('SAGI restore: backup file not found');
  process.exit(3);
}
if(process.env.SAGI_CONFIRM_RESTORE!=='YES'){
  console.error('SAGI restore: set SAGI_CONFIRM_RESTORE=YES to perform restore');
  process.exit(4);
}
function validStore(v){
  return v && typeof v==='object' && v.rooms && typeof v.rooms==='object' && v.licenses && typeof v.licenses==='object';
}
let raw=fs.readFileSync(source);
if(source.endsWith('.gz')) raw=zlib.gunzipSync(raw);
let payload;
try{payload=JSON.parse(raw.toString('utf8'))}catch(e){
  console.error('SAGI restore: invalid JSON');
  process.exit(5);
}
const store=payload?.store && validStore(payload.store) ? payload.store : payload;
if(!validStore(store)){
  console.error('SAGI restore: invalid SAGI store shape');
  process.exit(6);
}
fs.mkdirSync(path.dirname(DATA_FILE),{recursive:true});
if(fs.existsSync(DATA_FILE)){
  const pre=DATA_FILE+'.pre-restore-'+Date.now()+'.bak';
  fs.copyFileSync(DATA_FILE,pre);
}
const tmp=DATA_FILE+'.restore.tmp';
fs.writeFileSync(tmp,JSON.stringify(store,null,2));
fs.renameSync(tmp,DATA_FILE);
fs.copyFileSync(DATA_FILE,DATA_FILE+'.bak');
console.log(JSON.stringify({ok:true,rooms:Object.keys(store.rooms).length,licenses:Object.keys(store.licenses).length}));
