// Run: node training/tests/data-contract.test.cjs
// Source-level regression guards for data-loss incidents; browser E2E remains separate.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const home = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
const iq = fs.readFileSync(path.join(root, 'iq.html'), 'utf8');
const sw = fs.readFileSync(path.join(root, 'sw.js'), 'utf8');

assert.match(home, /function loadState\(\)/, 'training data loader missing');
assert.match(home, /x\.sessions\.every\(validSession\)/, 'training records must be validated before use');
assert.match(home, /function mutate\(fn\)[\s\S]*?loadState\(\)/, 'writes must re-read latest stored state');
assert.match(home, /function readIQ\(\)[\s\S]*?x\.every\(validIQ\)/, 'IQ data must not be silently filtered');
assert.match(home, /function validBackup\(x\)[\s\S]*?x\.iq\.every\(validIQ\)/, 'backup must validate every IQ record');
assert.match(home, /if\(!validBackup\(x\)\)throw Error\(\)/, 'restore must reject invalid backup');
assert.match(home, /if\(old===null\)localStorage\.removeItem\('sagi\.iq\.records'\)/, 'restore must roll back IQ records after failed save');
assert.match(home, /catch\{\$\('dailyProgress'\)\.textContent=/, 'unreadable IQ data must not display zero progress');
assert.match(home, /localStorage\.setItem\(key,JSON\.stringify\(next\)\)/, 'training save missing');
assert.match(iq, /sagi\.iq\.records/, 'IQ storage key changed without migration');
assert.match(sw, /const CACHE='sagi-training-/, 'offline cache version missing');
assert.doesNotMatch(home + iq, /<script[^>]+src=["']https?:/i, 'remote JavaScript dependency detected');
console.log('PASS: training and IQ data safety contract (static source checks only)');
