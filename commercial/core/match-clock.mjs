import { performance } from 'node:perf_hooks';

// Runtime-only monotonic clock. Persisted elapsedSeconds is a checkpoint,
// never an invitation to count downtime using an untrusted wall clock.
export function createMatchClock(checkpoint, { now = () => performance.now() } = {}) {
  let base = checkpoint.elapsedSeconds;
  let anchor = now();
  let running = false;
  let recoveryPending = checkpoint.running === true;
  function read() {
    const delta = running ? Math.max(0, Math.floor((now() - anchor) / 1000)) : 0;
    return { elapsedSeconds: Math.min(Number.MAX_SAFE_INTEGER, base + delta), running, recoveryPending };
  }
  function set(next) {
    if (!Number.isSafeInteger(next.elapsedSeconds) || next.elapsedSeconds < 0 || typeof next.running !== 'boolean') throw new Error('INVALID_CLOCK');
    base = next.elapsedSeconds;
    anchor = now();
    running = next.running;
    recoveryPending = false;
    return read();
  }
  return { read, set };
}
