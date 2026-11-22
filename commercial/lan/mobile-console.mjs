// Experimental same-origin mobile console; no external assets or persistent tokens.
export const mobileHtml = `<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>SAGI 手机控制</title><h1>SAGI 手机控制</h1><p>实验版 · 仅限受信任局域网</p><label>配对码 <input id="code" inputmode="numeric" maxlength="6" autocomplete="off"></label><button id="pair">配对</button><p id="status" role="status">未配对</p><h2 id="score">— : —</h2><button id="home" disabled>主队进球</button> <button id="away" disabled>客队进球</button><button id="refresh">同步比分</button><button id="retry" disabled>重试原指令</button><script src="/mobile.js" defer></script></html>`;
export const mobileJs = `'use strict';
const el = id => document.getElementById(id);
let token = '', state = null, pending = null, busy = false;
function controls() {
  el('home').disabled = el('away').disabled = !token || !state || busy || !!pending;
  el('retry').disabled = !token || !pending || busy;
  el('pair').disabled = busy || !!pending;
  el('refresh').disabled = busy;
}
async function api(route, body) {
  const r = await fetch('/api/v1/lan/' + route, {
    method: body ? 'POST' : 'GET', cache: 'no-store',
    headers: {'content-type':'application/json', ...(token ? {authorization:'Bearer '+token} : {})},
    body: body ? JSON.stringify(body) : undefined
  });
  const data = await r.json();
  if (!r.ok) throw Object.assign(new Error(data.error || 'HTTP_ERROR'), {status:r.status});
  return data;
}
async function sync() {
  state = null;
  const data = await api('state');
  state = data.state;
  if (!Number.isSafeInteger(state?.revision)) { state = null; throw new Error('INVALID_STATE'); }
  el('score').textContent = state.homeScore + ' : ' + state.awayScore;
}
async function run(action) {
  if (busy) return;
  busy = true; controls();
  try { await action(); }
  catch (e) { state = null; el('status').textContent = pending ? '结果待确认：请重试原指令，不要重复加分' : '连接或授权失败，请同步或重新配对'; }
  finally { busy = false; controls(); }
}
el('pair').onclick = () => run(async () => {
  token = ''; state = null;
  token = (await api('redeem', {code:el('code').value})).token;
  el('code').value = ''; await sync(); el('status').textContent = '已连接';
});
el('refresh').onclick = () => run(async () => { await sync(); el('status').textContent = pending ? '仍有待确认指令' : '已同步'; });
async function send() {
  try { await api('command', pending); }
  catch(e) {
    if (e.status === 409 || e.status === 400 || e.status === 403) {
      pending = null; await sync(); el('status').textContent = '指令未执行，请核对比分'; return;
    }
    throw e;
  }
  pending = null; await sync(); el('status').textContent = '已确认';
}
function goal(side) {
  if (!state || pending || busy) return;
  const bytes = new Uint8Array(16); crypto.getRandomValues(bytes);
  pending = {commandId:Array.from(bytes,b=>b.toString(16).padStart(2,'0')).join(''), expectedRevision:state.revision,type:'GOAL',side};
  run(send);
}
el('home').onclick = () => goal('HOME');
el('away').onclick = () => goal('AWAY');
el('retry').onclick = () => run(send);
window.addEventListener('beforeunload', e => { if(pending){e.preventDefault();e.returnValue='';} });
controls();`;
