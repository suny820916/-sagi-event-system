#!/usr/bin/env node
// Commercial release evidence runner. No third-party dependencies.
// Run from repository root: node commercial/tools/collect-release-evidence.mjs
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { createHash } from 'node:crypto';

const checks = [
  ['syntax:lan-gateway', 'commercial/lan/lan-gateway.mjs', true],
  ['syntax:lan-command-selftest', 'commercial/lan/lan-command-selftest.mjs', true],
  ['test:lan-command', 'commercial/lan/lan-command-selftest.mjs', false],
  ['test:engine-lan', 'commercial/lan/engine-lan-selftest.mjs', false],
  ['test:lan-state-revocation', 'commercial/lan/lan-state-revocation-selftest.mjs', false],
];
const run = (bin, args, timeout = 120000) => spawnSync(bin, args, {
  cwd: process.cwd(), encoding: 'utf8', timeout, maxBuffer: 1024 * 1024,
  windowsHide: true,
});
const sha256 = value => createHash('sha256').update(value).digest('hex');
const git = run('git', ['rev-parse', 'HEAD'], 10000);
const branch = run('git', ['branch', '--show-current'], 10000);
const revision = git.status === 0 ? git.stdout.trim() : null;
const branchName = branch.status === 0 ? branch.stdout.trim() : null;
const report = {
  schemaVersion: 1,
  createdAt: new Date().toISOString(),
  revision,
  branch: branchName,
  node: process.version,
  platform: process.platform,
  arch: process.arch,
  status: 'FAIL',
  checks: [],
};
if (!revision || branchName !== 'commercial-v1.0') {
  console.error('Refusing to run: checkout commercial-v1.0 with git metadata first.');
  process.exitCode = 2;
} else {
  for (const [name, path, syntaxOnly] of checks) {
    if (!existsSync(resolve(path))) {
      report.checks.push({ name, command: null, result: 'UNKNOWN', reason: 'FILE_MISSING' });
      continue;
    }
    const args = syntaxOnly ? ['--check', path] : [path];
    const result = run(process.execPath, args);
    const output = (result.stdout || '') + (result.stderr || '');
    const passed = result.status === 0 && !result.error;
    report.checks.push({
      name, command: ['node', ...args].join(' '),
      result: passed ? 'PASS' : 'FAIL',
      exitCode: result.status,
      signal: result.signal || null,
      errorCode: result.error?.code || null,
      outputSha256: sha256(output),
      // Deliberately omit stdout/stderr: logs can contain pairing credentials.
    });
    console.log(name + ': ' + (passed ? 'PASS' : 'FAIL'));
  }
  report.status = report.checks.every(c => c.result === 'PASS') ? 'PASS' : 'FAIL';
}
mkdirSync('commercial/evidence', { recursive: true });
const outputPath = 'commercial/evidence/release-evidence-local.json';
writeFileSync(outputPath, JSON.stringify(report, null, 2) + '\n', { mode: 0o600 });
console.log('Evidence: ' + outputPath + ' (' + report.status + ')');
if (report.status !== 'PASS') process.exitCode ||= 1;
