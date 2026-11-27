const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '..', 'index.html'), 'utf8');
const trainingKey = 'sagi.training.v1';
const iqKey = 'sagi.iq.records';

function boot() {
  const data = new Map();
  const elements = new Map();
  let download;
  let failTrainingWrite = false;
  const context = {
    Blob,
    URL: { createObjectURL(blob) { download = blob; return 'blob:test'; } },
    setTimeout() {},
    confirm: () => true,
    navigator: {},
    window: { addEventListener() {} },
    document: {
      getElementById(id) {
        if (!elements.has(id)) elements.set(id, {
          elements: { date: {}, name: {}, age: {}, position: {} },
          replaceChildren() {}, append() {}, removeAttribute() {}, reset() {},
        });
        return elements.get(id);
      },
      createElement: () => ({ click() {} }),
    },
    localStorage: {
      getItem: key => data.get(key) ?? null,
      setItem(key, value) {
        if (key === trainingKey && failTrainingWrite) throw Error('quota exceeded');
        data.set(key, value);
      },
      removeItem: key => data.delete(key),
    },
  };
  vm.runInNewContext(source.match(/<script>([\s\S]*?)<\/script>/)[1], context);
  return {
    data,
    export: async () => {
      elements.get('export').onclick();
      return JSON.parse(await download.text());
    },
    restore: async backup => {
      const input = elements.get('restore');
      input.files = [new Blob([JSON.stringify(backup)])];
      await input.onchange();
    },
    begin: () => elements.get('begin').onclick(),
    rejectTrainingWrite: () => { failTrainingWrite = true; },
  };
}

(async () => {
  const app = boot();
  const backup = {
    schema: 1,
    training: { profile: null, sessions: [], planStart: '2026-01-01' },
    iq: [{ scenario: 1, choice: 1, preferred: true, date: '2026-01-01T12:00:00Z' }],
  };
  await app.restore(backup);
  assert.deepEqual(await app.export(), backup);
  const stored = [...app.data];
  await app.restore({ ...backup, iq: [{ ...backup.iq[0], preferred: false }] });
  assert.deepEqual([...app.data], stored);
  app.rejectTrainingWrite();
  await app.restore({ ...backup, iq: [] });
  assert.deepEqual([...app.data], stored);
  const damaged = boot();
  damaged.data.set(trainingKey, '');
  damaged.begin();
  assert.equal(damaged.data.get(trainingKey), '');
  damaged.data.set(iqKey, '{bad IQ');
  const recovery = await damaged.export();
  assert.deepEqual(recovery, {
    format: 'sagi-training-raw-recovery', schema: 1,
    storage: { [trainingKey]: '', [iqKey]: '{bad IQ' },
  });
  await damaged.restore(recovery);
  assert.deepEqual(Object.fromEntries(damaged.data), recovery.storage);
})().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
