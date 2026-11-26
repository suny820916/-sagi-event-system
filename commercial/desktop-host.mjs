import { randomUUID } from 'node:crypto';
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
      if (command === 'scoreboard-on' || command === 'scoreboard-off') {
        try {
          const response = await fetch('http://127.0.0.1:' + runtime.engine.address.port + '/api/v1/commands', {
            method: 'POST', signal: AbortSignal.timeout(4000),
            headers: { authorization: 'Bearer ' + runtime.engine.token, 'content-type': 'application/json' },
            body: JSON.stringify({ commandId: randomUUID(), type: 'SET_SCOREBOARD', visible: command === 'scoreboard-on' }),
          });
          if (!response.ok) throw Error('SCOREBOARD_COMMAND_FAILED');
          reply({ ok: true });
        } catch {
          reply({ ok: false, error: 'SCOREBOARD_COMMAND_FAILED' });
        }
        continue;
      }
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
