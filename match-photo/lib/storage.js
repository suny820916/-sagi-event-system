'use strict';

const fs = require('fs');
const path = require('path');

function ensureDir(dir){
  fs.mkdirSync(dir,{recursive:true});
  return dir;
}

function storageLayout(root,eventId){
  const safeEvent=String(eventId||'unknown').replace(/[^A-Za-z0-9_-]/g,'_');
  const eventDir=ensureDir(path.join(root,'events',safeEvent));
  return {
    eventDir,
    originals:ensureDir(path.join(eventDir,'originals')),
    previews:ensureDir(path.join(eventDir,'previews'))
  };
}

function diskStats(root){
  if(typeof fs.statfsSync!=='function') return {supported:false};
  const s=fs.statfsSync(root);
  const block=Number(s.bsize||s.frsize||0);
  const free=Number(s.bavail||s.bfree||0)*block;
  const total=Number(s.blocks||0)*block;
  return {
    supported:true,
    freeBytes:free,
    totalBytes:total,
    freeGB:Number((free/1024/1024/1024).toFixed(2)),
    totalGB:Number((total/1024/1024/1024).toFixed(2))
  };
}

function assertCapacity(root,incomingBytes,minFreeGB){
  const stats=diskStats(root);
  if(!stats.supported) return stats;
  const reserve=Number(minFreeGB||0)*1024*1024*1024;
  if(stats.freeBytes-incomingBytes<reserve){
    const err=new Error('服务器剩余空间不足，已停止上传，请先扩容或清理存储');
    err.code='LOW_DISK_SPACE';
    err.stats=stats;
    throw err;
  }
  return stats;
}

module.exports={ensureDir,storageLayout,diskStats,assertCapacity};
