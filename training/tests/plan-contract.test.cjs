// Run: node training/tests/plan-contract.test.cjs
// Guards the 28-day plan and the 20-scenario decision bank against silent drift.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const home = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
const iq = fs.readFileSync(path.join(root, 'iq.html'), 'utf8');
const vm = require('node:vm');

const dayStart = home.indexOf("$('daily').textContent=day?[");
const dayEnd = home.indexOf("][Math.min(27,day-1)]", dayStart);
assert.ok(dayStart >= 0 && dayEnd > dayStart, '28-day plan expression missing');
const planSource = home.slice(dayStart).match(/\?\[([\s\S]*?)\]\[Math\.min\(27,day-1\)\]/);
assert.ok(planSource, 'day descriptions missing');
const days = vm.runInNewContext('[' + planSource[1] + ']');
assert.equal(days.length, 28, 'exactly 28 day descriptions required');
assert.ok(days.every(d => typeof d === 'string' && d.trim().length >= 8), 'blank or short training day');

const questionStart = iq.indexOf('const q=');
const categoryStart = iq.indexOf('const categories=');
assert.ok(questionStart >= 0 && categoryStart > questionStart, 'scenario bank missing');
const bank = iq.slice(questionStart, categoryStart);
const sandbox = {};
vm.runInNewContext(bank.replace('const q=', 'var q='), sandbox, {timeout: 1000});
assert.equal(sandbox.q.length, 20, 'expected 20 decision scenarios');
for (const [i, s] of sandbox.q.entries()) {
  assert.ok(typeof s.t === 'string' && s.t.trim().length > 10, 'missing question ' + (i+1));
  assert.ok(Array.isArray(s.a) && s.a.length === 3, 'choices must have three entries: ' + (i+1));
  assert.ok(s.a.every(a => typeof a === 'string' && a.trim()), 'blank choice ' + (i+1));
  assert.ok(Number.isInteger(s.c) && s.c >= 0 && s.c < s.a.length, 'invalid correct answer ' + (i+1));
  assert.ok(Array.isArray(s.p) && s.p.length >= 2, 'missing pitch context ' + (i+1));
  assert.ok(typeof s.f === 'string' && s.f.trim().length >= 10, 'missing explanation ' + (i+1));
}
console.log('PASS: 28-day training plan and 20 decision scenarios');

const drillSource = iq.slice(iq.indexOf('const dailyDrills='), iq.indexOf('const dailyDrill='));
const drillForHash = vm.runInNewContext(drillSource + '\ndrillForHash');
for (let day = 1; day <= days.length; day++) {
  const drill = drillForHash('#day=' + day);
  assert.equal(drill.day, day);
  assert.equal(drill.scenarios.length, 3);
  assert.equal(new Set(drill.scenarios).size, 3);
  assert.ok(drill.scenarios.every(id => Number.isInteger(id) && sandbox.q[id - 1]));
}
for (const hash of ['', '#day=0', '#day=29', '#day=01', '#day=3&other=1']) {
  assert.equal(drillForHash(hash), null);
}
