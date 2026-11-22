// Experimental same-origin mobile console; no external assets or persistent tokens.
export const mobileHtml = `<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>SAGI 手机控制</title><h1>SAGI 手机控制</h1><p>实验版 · 仅限受信任局域网</p><label>配对码 <input id="code" inputmode="numeric" maxlength="6" autocomplete="off"></label><button id="pair">配对</button><p id="status" role="status">未配对</p><h2 id="score">— : —</h2><button id="home" disabled>主队进球</button> <button id="away" disabled>客队进球</button><p><label>球员号码 <input id="number" inputmode="numeric" maxlength="3"></label> <label>换上号码 <input id="onNumber" inputmode="numeric" maxlength="3"></label></p><button id="homeYellow" disabled>主队黄牌</button> <button id="awayYellow" disabled>客队黄牌</button> <button id="homeRed" disabled>主队红牌</button> <button id="awayRed" disabled>客队红牌</button> <button id="homeSub" disabled>主队换人</button> <button id="awaySub" disabled>客队换人</button><p><button id="refresh">同步比分</button><button id="retry" disabled>重试原指令</button></p><script src="/mobile.js" defer></script></html>`;
export const mobileJs = `'use strict';
const el = id => document.getElementById(id);
let token = '', state = null, pending = null, busy = false, storageReady = true;
const eventButtons = ['home','away','homeYellow','awayYellow','homeRed','awayRed','homeSub','awaySub'];
function validNumber(value) { return typeof value === 'string' && /^[0-9]{1,3}$/.test(value); }
function validIntent(c) {
  if (c.type === 'GOAL') return true;
  if (c.type === 'YELLOW' || c.type === 'RED') return validNumber(c.player?.number);
  if (c.type === 'SUB') return validNumber(c.off?.number) && validNumber(c.on?.number) && Number(c.off.number) !== Number(c.on.number);
  return false;
}
const pendingKey = 'sagi.mobile.pending.v1';
try {
  const raw = sessionStorage.getItem(pendingKey);
  if (raw) {
    pending = JSON.parse(raw);
    if (!pending || typeof pending.fixtureId !== 'string' || !pending.fixtureId ||
        !/^[a-f0-9]{32}$/.test(pending.commandId) || !validIntent(pending) ||
        !['HOME','AWAY'].includes(pending.side) || !Number.isSafeInteger(pending.expectedRevision) || pending.expectedRevision < 0)
      throw new Error('INVALID_PENDING');
  }
} catch { storageReady = false; }
function clearPending() {
  sessionStorage.removeItem(pendingKey);
  pending = null;
}
function matchesFixture() { return !!state && !!pending && state.fixtureId === pending.fixtureId; }
let lastSync = 0;
function fresh() { const age = Date.now() - lastSync; return !!state && age >= 0 && age <= 5000; }
function controls() {
  for (const id of eventButtons) el(id).disabled = !storageReady || !token || !fresh() || busy || !!pending;
  el('retry').disabled = !storageReady || !token || !matchesFixture() || !fresh() || busy;
  el('pair').disabled = busy;
  el('refresh').disabled = busy;
}
async function api(route, body) {
  const r = await fetch('/api/v1/lan/' + route, {
    method: body ? 'POST' : 'GET', cache: 'no-store', signal: AbortSignal.timeout(8000),
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
  if (!Number.isSafeInteger(state?.revision) || state.revision < 0 || !Number.isSafeInteger(state.homeScore) || state.homeScore < 0 || !Number.isSafeInteger(state.awayScore) || state.awayScore < 0 || typeof state.fixtureId !== 'string' || !state.fixtureId) { state = null; throw new Error('INVALID_STATE'); }
  lastSync = Date.now();
  el('score').textContent = state.homeScore + ' : ' + state.awayScore;
}
async function run(action) {
  if (busy) return;
  busy = true; controls();
  try { await action(); }
  catch (e) { state = null; if (e.status === 401) token = ''; el('score').textContent = '— : —'; el('status').textContent = pending ? '结果待确认：请重试原指令，不要重复操作' : '连接或授权失败，请同步或重新配对'; }
  finally { busy = false; controls(); }
}
el('pair').onclick = () => run(async () => {
  token = ''; state = null;
  token = (await api('redeem', {code:el('code').value})).token;
  el('code').value = ''; await sync(); el('status').textContent = pending ? (matchesFixture() ? '请重试原指令' : '比赛不一致，请联系导播核对') : '已连接';
});
el('refresh').onclick = () => run(async () => { await sync(); el('status').textContent = pending ? '仍有待确认指令' : '已同步'; });
async function send() {
  if (!storageReady || !matchesFixture() || !fresh()) throw new Error('FIXTURE_MISMATCH');
  try { await api('command', pending); }
  catch(e) {
    if (e.status === 409 || e.status === 400 || e.status === 403) {
      await sync();
      if (!matchesFixture()) throw new Error('FIXTURE_MISMATCH');
      clearPending(); el('status').textContent = '指令已结束，请核对比分'; return;
    }
    throw e;
  }
  clearPending(); await sync(); el('status').textContent = '已确认';
}
function eventCommand(side, type = 'GOAL') {
  if (!storageReady || !token || !fresh() || pending || busy) return;
  const number = el('number').value.trim(), on = el('onNumber').value.trim();
  const details = type === 'SUB' ? {off:{number},on:{number:on}} : type === 'GOAL' ? {} : {player:{number}};
  if (!validIntent({type,...details})) { el('status').textContent = '请输入有效且不同的球员号码'; return; }
  const bytes = new Uint8Array(16); crypto.getRandomValues(bytes);
  pending = {commandId:Array.from(bytes,b=>b.toString(16).padStart(2,'0')).join(''), expectedRevision:state.revision,fixtureId:state.fixtureId,type,side,...details};
  try { sessionStorage.setItem(pendingKey, JSON.stringify(pending)); }
  catch { storageReady = false; el('status').textContent = '无法保存指令，已禁止赛事操作'; controls(); return; }
  run(send);
}
el('home').onclick = () => eventCommand('HOME');
el('away').onclick = () => eventCommand('AWAY');
for (const [suffix,type] of [['Yellow','YELLOW'],['Red','RED'],['Sub','SUB']]) {
  el('home'+suffix).onclick = () => eventCommand('HOME',type);
  el('away'+suffix).onclick = () => eventCommand('AWAY',type);
}
el('retry').onclick = () => run(send);
window.addEventListener('pageshow', () => { lastSync = 0; controls(); });
window.addEventListener('beforeunload', e => { if(pending){e.preventDefault();e.returnValue='';} });
if (!storageReady) el('status').textContent = '无法恢复本地指令，已禁止赛事操作';
else if (pending) el('status').textContent = '存在待确认指令，请重新配对';
controls();
// Poll only when idle; never replay a mutation automatically.
window.setInterval(() => {
  if (!token || busy) return;
  run(async () => {
    await sync();
    el('status').textContent = pending ? (matchesFixture() ? '结果待确认，请重试原指令' : '比赛不一致，请联系导播核对') : '已连接 · 自动同步';
  });
}, 2000);`;
