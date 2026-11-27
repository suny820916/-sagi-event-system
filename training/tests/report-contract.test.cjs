// Run: node training/tests/report-contract.test.cjs
// Guards the same-difficulty coaching recommendation against misleading mixed-level summaries.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const iq = fs.readFileSync(path.join(__dirname, '..', 'iq.html'), 'utf8');
const home = fs.readFileSync(path.join(__dirname, '..', 'index.html'), 'utf8');
const sw = fs.readFileSync(path.join(__dirname, '..', 'sw.js'), 'utf8');

assert.match(home, /V0\.11 个人训练版/, 'training version label must advance');
assert.match(iq, /体验版 0\.11/, 'IQ version label must advance');
assert.match(iq, /id="coach"/, 'coaching recommendation output missing');
assert.match(iq, /function coachAdvice\(rows\)/, 'coaching recommendation logic missing');
assert.match(iq, /filter\(r=>r\.limitMs===latest\)\.slice\(-20\)/, 'recommendation must use recent records at the same difficulty');
assert.match(iq, /sample\.length<12\|\|stats\.some\(x=>x\.n<2\)/, 'recommendation must require enough category coverage');
assert.match(iq, /数据不足：/, 'insufficient-data state must be explicit');
assert.match(iq, /\$\('coach'\)\.textContent=coachAdvice\(rows\)/, 'report must render the coaching recommendation');
assert.match(iq, /version:'0\.11'/, 'new IQ records must carry the current scenario version');
assert.match(sw, /const CACHE='sagi-training-11-r1'/, 'frontend change must rotate the offline cache');
console.log('PASS: same-difficulty coaching recommendation, minimum sample guard and V0.11 cache rotation');
