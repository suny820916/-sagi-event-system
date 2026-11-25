import { createInterface } from 'node:readline';
import { startCommercialRuntime } from './runtime.mjs';

const reply = value => process.stdout.write(JSON.stringify(value) + '\n');
try {
  const options = JSON.parse(process.env.SAGI_DESKTOP_OPTIONS ?? '{}');
  const runtime = await startCommercialRuntime(options);
  const input = createInterface({ input: process.stdin, crlfDelay: Infinity });
  try {
    reply({ ok: true, mobileUrl: runtime.mobileUrl, broadcastUrl: runtime.broadcastUrl });
    for await (const command of input) {
      if (command === 'close') break;
      if (command !== 'pair') {
        reply({ ok: false, error: 'INVALID_OPERATOR_COMMAND' });
        continue;
      }
      try {
        reply({ ok: true, code: runtime.approvePhonePairing().code });
      } catch {
        reply({ ok: false, error: 'PAIRING_FAILED' });
      }
    }
  } finally {
    input.close();
    process.stdin.pause();
    await runtime.close();
  }
} catch (error) {
  reply({ ok: false, error: error.code ?? error.message });
  process.exitCode = 1;
}
