const test=require('node:test');
const assert=require('node:assert/strict');
const {normalizeCode,makeDownloadCode}=require('../lib/download-code');

test('normalizes download codes',()=>{
  assert.equal(normalizeCode('abcde-23456'),'ABCDE23456');
  assert.equal(normalizeCode(' ABCDE 23456 '),'ABCDE23456');
});

test('generates human-friendly 10-character code',()=>{
  const code=makeDownloadCode([]);
  assert.match(code,/^[A-HJ-NP-Z2-9]{5}-[A-HJ-NP-Z2-9]{5}$/);
  assert.equal(normalizeCode(code).length,10);
});

test('avoids an existing code',()=>{
  const existing=[];
  for(let i=0;i<50;i++){
    const code=makeDownloadCode(existing);
    assert.ok(!existing.some(x=>normalizeCode(x.downloadCode)===normalizeCode(code)));
    existing.push({downloadCode:code});
  }
});
