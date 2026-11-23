// Run: node training/tests/static-contract.test.cjs
// Static deployment contract: no external assets, all offline shell resources exist.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const read = name => fs.readFileSync(path.join(root, name), 'utf8');
const files = ['index.html', 'iq.html', 'sw.js', 'manifest.webmanifest', 'icon.svg'];
for (const file of files) assert.ok(fs.statSync(path.join(root, file)).size > 0, file);
const sw = read('sw.js');
const match = sw.match(/const FILES=\[([^\]]+)\]/);
assert.ok(match, 'service worker must declare precache');
const cached = [...match[1].matchAll(/'\.\/([^']*)'/g)].map(m => m[1] || 'index.html');
for (const file of ['index.html', 'iq.html', 'manifest.webmanifest', 'icon.svg'])
  assert.ok(cached.includes(file), 'missing offline asset: ' + file);
for (const html of ['index.html', 'iq.html']) {
  const page = read(html);
  assert.match(page, /<meta name="viewport"/);
  assert.match(page, /manifest\.webmanifest/);
  assert.doesNotMatch(page, /<script[^>]+src=["']https?:/i, 'remote scripts forbidden');
  assert.doesNotMatch(page, /<link[^>]+href=["']https?:/i, 'remote CSS forbidden');
}
const manifest = JSON.parse(read('manifest.webmanifest'));
assert.equal(manifest.scope, './');
assert.equal(manifest.start_url, './index.html');
assert.equal(manifest.display, 'standalone');
assert.ok(manifest.icons.every(i => fs.existsSync(path.join(root, i.src))));
assert.match(read('iq.html'), /const categories=/);
assert.match(read('index.html'), /function validBackup\(/);
console.log('PASS: static shell, offline assets, PWA manifest and backup hooks');
