import { open, mkdir } from 'node:fs/promises';
import { resolve, join } from 'node:path';
import { createHash } from 'node:crypto';

// A claim is never automatically removed, even if output fails.
// Use a dedicated local directory, never a shared network drive.
export class FileCueClaims {
  constructor(directory) {
    if (typeof directory !== 'string' || !directory.trim()) throw Error('CLAIM_DIRECTORY_REQUIRED');
    this.directory = resolve(directory);
  }
  async claim(cueId) {
    if (typeof cueId !== 'string' || !/^[A-Za-z0-9_-]{8,128}$/.test(cueId)) throw Error('INVALID_CUE_ID');
    await mkdir(this.directory, { recursive: true });
    const name = createHash('sha256').update(cueId).digest('hex') + '.claim';
    let file;
    try { file = await open(join(this.directory, name), 'wx', 0o600); }
    catch (error) { if (error.code === 'EEXIST') return false; throw error; }
    try { await file.writeFile(cueId + '\n', 'utf8'); await file.sync(); }
    finally { await file.close(); }
    return true;
  }
}
