// Experimental same-origin mobile console; no external assets or persistent tokens.
export const mobileHtml = `<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>SAGI 手机控制</title><h1>SAGI 手机控制</h1><p>实验版 · 仅限受信任局域网</p><label>配对码 <input id="code" inputmode="numeric" maxlength="6" autocomplete="off"></label><button id="pair">配对</button><p id="status" role="status">未配对</p><h2 id="score">— : —</h2><p id="clock">计时未同步</p><button id="clockStart" disabled>开始计时</button> <button id="clockPause" disabled>暂停计时</button><button id="home" disabled>主队进球</button> <button id="away" disabled>客队进球</button><p><label>球员号码 <input id="number" inputmode="numeric" maxlength="3"></label> <label>换上号码 <input id="onNumber" inputmode="numeric" maxlength="3"></label></p><button id="homeYellow" disabled>主队黄牌</button> <button id="awayYellow" disabled>客队黄牌</button> <button id="homeRed" disabled>主队红牌</button> <button id="awayRed" disabled>客队红牌</button> <button id="homeSub" disabled>主队换人</button> <button id="awaySub" disabled>客队换人</button><h2 id="penScore">点球未同步</h2><p id="penHome">主队：—</p><p id="penAway">客队：—</p><button id="homePenScore" disabled>主队罚进</button> <button id="homePenMiss" disabled>主队罚失</button> <button id="awayPenScore" disabled>客队罚进</button> <button id="awayPenMiss" disabled>客队罚失</button><button id="penUndo" disabled>撤销最后一次罚球</button><p id="penUndoTarget"></p><p><button id="refresh">同步比分</button><button id="retry" disabled>重试原指令</button></p><script src="/mobile.js" defer></script></html>`;
export const mobileJs = `'use strict';
const el = id => document.getElementById(id);
let token = '', state = null, pending = null, busy = false, storageReady = true;
const eventButtons = ['home','away','homeYellow','awayYellow','homeRed','awayRed','homeSub','awaySub'];
function validNumber(value) { return typeof value === 'string' && /^[0-9]{1,3}$/.test(value); }
const playing = ['1H','2H','ET1','ET2'];
const penButtons = ['homePenScore','homePenMiss','awayPenScore','awayPenMiss'];
function validPen(p) { return p && typeof p.started === 'boolean' && typeof p.finished === 'boolean' && Number.isSafeInteger(p.home) && p.home >= 0 && Number.isSafeInteger(p.away) && p.away >= 0; }
function validAttemptId(id) { return typeof id === 'string' && id.length > 0 && id.length <= 512; }
function undoTarget(p) {
  if (!validPen(p) || !p.started || p.finished || !Array.isArray(p.history) || !p.history.length) return null;
  if (!p.history.every(a => a && validAttemptId(a.attemptId) && ['HOME','AWAY'].includes(a.side) && ['SCORED','MISSED'].includes(a.outcome)) || new Set(p.history.map(a=>a.attemptId)).size !== p.history.length) return null;
  if (!['HOME','AWAY'].every(side => p.history.filter(a=>a.side===side && a.outcome==='SCORED').length===p[side==='HOME'?'home':'away'])) return null;
  return p.history[p.history.length-1];
}
function renderPenaltyHistory(p) {
  const valid = validPen(p) && p.started && Array.isArray(p.history) &&
    p.history.every(a => a && ['HOME','AWAY'].includes(a.side) && ['SCORED','MISSED'].includes(a.outcome)) &&
    ['HOME','AWAY'].every(side => p.history.filter(a => a.side === side && a.outcome === 'SCORED').length === p[side === 'HOME' ? 'home' : 'away']);
  for (const [id,side,label] of [['penHome','HOME','主队'],['penAway','AWAY','客队']]) {
    const marks = valid ? p.history.filter(a => a.side === side).map((a,i) => (i+1)+':'+(a.outcome === 'SCORED' ? '●' : '○')).join(' ') : '';
    el(id).textContent = label+'：'+(marks || (valid ? '尚未罚球' : '—'));
  }
}
function validIntent(c) {
  if (c.type === 'UNDO_PENALTY_ATTEMPT') return validAttemptId(c.attemptId) && !('side' in c);
  if (c.type === 'PENALTY_ATTEMPT') return ['SCORED','MISSED'].includes(c.outcome);
  if (c.type === 'SET_CLOCK_RUNNING') return typeof c.running === 'boolean' && !('elapsedSeconds' in c) && !('side' in c);
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
        (!['SET_CLOCK_RUNNING','UNDO_PENALTY_ATTEMPT'].includes(pending.type) && !['HOME','AWAY'].includes(pending.side)) || !Number.isSafeInteger(pending.expectedRevision) || pending.expectedRevision < 0)
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
  for (const id of penButtons) el(id).disabled = !storageReady || !token || !fresh() || busy || !!pending || state?.period !== 'PEN' || !validPen(state?.penalties) || !state.penalties.started || state.penalties.finished;
  const target = undoTarget(state?.penalties);
  el('penUndo').disabled = !storageReady || !token || !fresh() || busy || !!pending || state?.period !== 'PEN' || !target;
  el('penUndoTarget').textContent = fresh() && state?.period === 'PEN' && target ? '最后一次：'+(target.side==='HOME'?'主队':'客队')+' '+(target.outcome==='SCORED'?'罚进':'罚失') : '';
  const clockReady = storageReady && token && fresh() && !busy && !pending && !!state.clock && typeof state.clock.running === 'boolean' && Number.isSafeInteger(state.clock.elapsedSeconds) && state.clock.elapsedSeconds >= 0;
  el('clockStart').disabled = !clockReady || !playing.includes(state?.period) || state?.clock?.running;
  el('clockPause').disabled = !clockReady || !state?.clock?.running;
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
  const p = state.penalties;
  el('penScore').textContent = validPen(p) && p.started ? '点球 '+p.home+' : '+p.away+(p.finished?' · 已结束':'') : '点球未开始或未同步';
  renderPenaltyHistory(p);
  el('score').textContent = state.homeScore + ' : ' + state.awayScore;
  const periods = {PRE:'赛前','1H':'上半场',HT:'中场','2H':'下半场',ET1:'加时上半场',ET_BREAK:'加时中场',ET2:'加时下半场',PEN:'点球大战',FT:'全场结束'};
  const c = state.clock;
  el('clock').textContent = c && Number.isSafeInteger(c.elapsedSeconds) && c.elapsedSeconds >= 0 && typeof c.running === 'boolean' ? (periods[state.period] || '未知阶段') + ' · ' + Math.floor(c.elapsedSeconds/60) + ':' + String(c.elapsedSeconds%60).padStart(2,'0') + (c.running?' · 运行中':' · 已暂停') : '计时未同步';
}
async function run(action) {
  if (busy) return;
  busy = true; controls();
  try { await action(); }
  catch (e) { state = null; if (e.status === 401) token = ''; el('score').textContent = '— : —'; el('clock').textContent = '计时未同步'; el('penScore').textContent = '点球未同步'; renderPenaltyHistory(null); el('status').textContent = pending ? '结果待确认：请重试原指令，不要重复操作' : '连接或授权失败，请同步或重新配对'; }
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
  queueIntent({type,side,...details});
}
function queueIntent(intent) {
  if (!storageReady || !token || !fresh() || pending || busy || !validIntent(intent)) return;
  const bytes = new Uint8Array(16); crypto.getRandomValues(bytes);
  pending = {commandId:Array.from(bytes,b=>b.toString(16).padStart(2,'0')).join(''), expectedRevision:state.revision,fixtureId:state.fixtureId,...intent};
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
el('clockStart').onclick = () => { if (!el('clockStart').disabled) queueIntent({type:'SET_CLOCK_RUNNING',running:true}); };
el('clockPause').onclick = () => { if (!el('clockPause').disabled) queueIntent({type:'SET_CLOCK_RUNNING',running:false}); };
for (const [id,side,outcome] of [['homePenScore','HOME','SCORED'],['homePenMiss','HOME','MISSED'],['awayPenScore','AWAY','SCORED'],['awayPenMiss','AWAY','MISSED']]) {
  el(id).onclick = () => { if (!el(id).disabled) queueIntent({type:'PENALTY_ATTEMPT',side,outcome}); };
}
el('penUndo').onclick = () => {
  if (el('penUndo').disabled || !fresh()) return;
  const target = undoTarget(state?.penalties);
  if (target && state.period === 'PEN') queueIntent({type:'UNDO_PENALTY_ATTEMPT',attemptId:target.attemptId});
};
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
