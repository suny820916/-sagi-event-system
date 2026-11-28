import fs from 'node:fs';
import { gzipSync, gunzipSync } from 'node:zlib';

const option = process.argv[2];
if (process.argv.length > 3 || (option && option !== '--update')) {
  throw new Error('Usage: node intro/tests/v433-auto-test-v10-payload.mjs [--update]');
}
const packagePath = new URL('../SAGI_AUTO_TEST_V10.bat', import.meta.url);
const original = fs.readFileSync(packagePath, 'utf8');
const normalize = text => text.replace(/\r\n/g, '\n').replace(/\n+$/, '');
let result = original;
for (const [kind, filename] of [['CONTROL', 'v45-lan.html'], ['OUTPUT', 'vmix-v45-lan.html']]) {
  const source = normalize(fs.readFileSync(new URL('../' + filename, import.meta.url), 'utf8'));
  const marker = new RegExp('(^###' + kind + '###\\r?\\n)([A-Za-z0-9+/=]+)', 'm');
  const embedded = result.match(marker);
  if (!embedded) throw new Error('AUTO TEST V1.0 is missing the ' + kind + ' payload');
  const html = gunzipSync(Buffer.from(embedded[2], 'base64')).toString('utf8');
  if (normalize(html) === source) continue;
  if (option !== '--update') {
    throw new Error(kind + ' differs from ' + filename + '. Run this check with --update to repack.');
  }
  result = result.replace(marker, (_, prefix) => prefix + gzipSync(source, { level: 9 }).toString('base64'));
}
if (result !== original) fs.writeFileSync(packagePath, result, 'utf8');
console.log('AUTO TEST V1.0 control and output match the V4.33 candidate.');
