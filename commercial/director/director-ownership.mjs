import { open, unlink } from 'node:fs/promises';
import { resolve } from 'node:path';

// All cooperating directors for one vMix endpoint must share the same local path.
// Never reclaim a latch by age or PID: an outstanding Cut may still take effect.
export class DirectorOwnership {
  constructor(path) {
    if (typeof path !== 'string' || !path.trim()) throw Error('OWNERSHIP_PATH_REQUIRED');
    this.path = resolve(path);
  }
  async acquire() {
    let handle;
    try { handle = await open(this.path, 'wx', 0o600); }
    catch (error) { if (error.code === 'EEXIST') return null; throw error; }
    try { await handle.writeFile('SAGI director ownership; reconcile output before removal\n'); await handle.sync(); }
    finally { await handle.close(); }
    let released = false;
    const path = this.path;
    return async () => {
      if (released) throw Error('OWNERSHIP_ALREADY_RELEASED');
      released = true;
      await unlink(path);
    };
  }
}
