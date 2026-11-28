import fs from 'node:fs';
import assert from 'node:assert/strict';

const path = new URL('../SAGI_V433_FIELD_ACCEPTANCE_SELF_CONTAINED.bat', import.meta.url);
const src = fs.readFileSync(path, 'utf8');

assert.match(src,/###SAGI_ACCEPTANCE_PS###/,'embedded PowerShell marker missing');
assert.match(src,/SAGI_V433_FIELD_ACCEPTANCE_V2/,'report schema missing');
assert.match(src,/bridge-port-8100/,'Bridge port gate missing');
assert.match(src,/vmix-api-8088/,'vMix API gate missing');
assert.match(src,/\/health/,'Bridge health gate missing');
assert.match(src,/SAGI433_PENALTY_RC1/,'V4.33 runtime marker gate missing');
assert.match(src,/SAGI432_SIGNATURE_RC7/,'Signature runtime marker gate missing');
assert.match(src,/Start-Process 'http:\/\/127\.0\.0\.1:8100\/'/,'local control auto-open missing');
assert.doesNotMatch(src,/_SAGI_AUTO_TEST\.ps1/i,'must never depend on stale TEMP acceptance script');
assert.doesNotMatch(src,/%TEMP%|\\\\Temp\\\\/i,'must not depend on Windows TEMP path');
assert.doesNotMatch(src,/powershell(?:\.exe)?[^\r\n]*\s-File\s/i,'launcher must execute embedded payload, not an external ps1');

console.log('PASS v4.33 self-contained field acceptance launcher gate');
