import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { fileURLToPath } from 'node:url';

const HERE=path.dirname(fileURLToPath(import.meta.url));
const DATA_FILE=process.env.SAGI_DATA_FILE || path.join(HERE,'data.json');
const BACKUP_DIR=process.env.SAGI_BACKUP_DIR || path.join(path.dirname(DATA_FILE),'backups');
const RETENTION=Math.max(1,Math.min(365,Number(process.env.SAGI_BACKUP_RETENTION_DAYS || 14)));

function stamp(d=new Date()){
  const p=n=>String(n).padStart(2,'0');
  return d.getFullYear()+p(d.getMonth()+1)+p(d.getDate())+'-'+p(d.getHours())+p(d.getMinutes())+p(d.getSeconds());
}
function validStore(v){
  return v && typeof v==='object' && v.rooms && typeof v.rooms==='object' && v.licenses && typeof v.licenses==='object';
}
if(!fs.existsSync(DATA_FILE)){
  console.error('SAGI backup: data file not found');
  process.exit(2);
}
let raw;
try{
  raw=fs.readFileSync(DATA_FILE);
  const parsed=JSON.parse(raw.toString('utf8'));
  if(!validStore(parsed)) throw new Error('invalid_store_shape');
}catch(e){
  console.error('SAGI backup: source data invalid:',e.message);
  process.exit(3);
}
fs.mkdirSync(BACKUP_DIR,{recursive:true});
const filename='sagi-pool-'+stamp()+'.json.gz';
const outPath=path.join(BACKUP_DIR,filename);
const tmp=outPath+'.tmp';
fs.writeFileSync(tmp,zlib.gzipSync(raw,{level:9}));
fs.renameSync(tmp,outPath);

const cutoff=Date.now()-RETENTION*86400000;
const files=fs.readdirSync(BACKUP_DIR)
  .filter(n=>/^sagi-pool-\d{8}-\d{6}\.json\.gz$/.test(n))
  .map(n=>({name:n,path:path.join(BACKUP_DIR,n),mtime:fs.statSync(path.join(BACKUP_DIR,n)).mtimeMs}))
  .sort((a,b)=>b.mtime-a.mtime);

let removed=0;
for(const item of files){
  if(item.mtime<cutoff){
    try{fs.rmSync(item.path,{force:true});removed++}catch{}
  }
}
const size=fs.statSync(outPath).size;
console.log(JSON.stringify({ok:true,file:filename,sizeBytes:size,retentionDays:RETENTION,removedOldBackups:removed}));
