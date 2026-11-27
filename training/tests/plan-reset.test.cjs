// Run: node training/tests/plan-reset.test.cjs
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '..', 'index.html'), 'utf8');
const sw = fs.readFileSync(path.join(__dirname, '..', 'sw.js'), 'utf8');
assert.match(source, /mutate\(latest=>\(\{profile:null,sessions:\[\],planStart:undefined\}\)\)/, 'clear must reset the 28-day plan');
assert.match(source, /if\(confirm\('确定清空训练中心数据？决策记录仍保留。'\)\)/, 'clear requires confirmation and preserves IQ records');
assert.match(source, /planStart:latest\.planStart\|\|d/, 'new plan must start after reset');
const revision = sw.match(/const CACHE='sagi-training-10-r(\d+)'/);
assert.ok(revision && Number(revision[1]) >= 31, 'cache must include the plan reset fix');
console.log('training plan reset regression checks passed');
