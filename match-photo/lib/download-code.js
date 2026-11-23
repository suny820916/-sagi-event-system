'use strict';

const crypto = require('crypto');
const ALPHABET='ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

function normalizeCode(value){
  return String(value||'').toUpperCase().replace(/[^A-Z0-9]/g,'');
}

function makeDownloadCode(orders=[]){
  for(let attempt=0;attempt<50;attempt++){
    let raw='';
    for(let i=0;i<10;i++) raw+=ALPHABET[crypto.randomInt(0,ALPHABET.length)];
    const code=raw.slice(0,5)+'-'+raw.slice(5);
    const normalized=normalizeCode(code);
    if(!orders.some(o=>normalizeCode(o.downloadCode)===normalized)) return code;
  }
  throw new Error('无法生成唯一下载码');
}

module.exports={normalizeCode,makeDownloadCode};
