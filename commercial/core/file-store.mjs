import { copyFile, mkdir, open, readFile, rename, rm, rmdir, stat, writeFile } from "node:fs/promises";
import path from "node:path";
import { createReadStream } from "node:fs";
import { hydrateMatchState } from "./match-core.mjs";

async function readJson(file) {
  return JSON.parse(await readFile(file, "utf8"));
}

function parseJournal(text) {
  const lines = text.split("\n");
  const complete = lines.slice(0, -1);
  const entries = [];
  for (const line of complete) {
    if (!line.trim()) continue;
    const entry = JSON.parse(line);
    entries.push(entry);
  }
  return entries;
}

export class FileMatchStore {
  constructor(rootDir) {
    if (!rootDir) throw new Error("ROOT_DIR_REQUIRED");
    this.rootDir = rootDir;
    this.snapshotPath = path.join(rootDir, "match-state.json");
    this.backupPath = path.join(rootDir, "match-state.bak.json");
    this.journalPath = path.join(rootDir, "match-events.jsonl");
    this.lockPath = path.join(rootDir, "match-writer.lock");
    this.pending = Promise.resolve();
    this.journalError = null;
    this.snapshotError = null;
    this.journalCache = null;
  }

  async init() {
    await mkdir(this.rootDir, { recursive: true });
    return this;
  }

  async _entries() {
    try {
      const text = await readFile(this.journalPath, "utf8");
      if (text.length && !text.endsWith("\n")) this.journalError = "TORN_JOURNAL_REQUIRES_REPAIR";
      return parseJournal(text);
    } catch (error) {
      if (error.code === "ENOENT") return [];
      throw error;
    }
  }

  // Retain only the latest commit while validating every complete record.
  // UTF-8 stream decoding preserves multibyte player names across chunks.
  async _journalFingerprint() {
    try {
      const s = await stat(this.journalPath, { bigint: true });
      return [s.dev, s.ino, s.size, s.mtimeNs, s.ctimeNs].join(':');
    } catch (error) {
      if (error.code === 'ENOENT') return null;
      throw error;
    }
  }

  async _lastCommit({ useCache = false } = {}) {
    const before = await this._journalFingerprint();
    if (before === null) {
      if (this.journalCache !== null) throw new Error('JOURNAL_DISAPPEARED');
      // Snapshots are only produced after a journal commit. They cannot
      // establish the latest clock or command history without that journal.
      for (const file of [this.snapshotPath, this.backupPath]) {
        let exists = false;
        try { await stat(file); exists = true; }
        catch (error) { if (error.code !== 'ENOENT') throw error; }
        if (exists) throw new Error('JOURNAL_DISAPPEARED');
      }
    }
    if (useCache && before !== null && this.journalCache?.fingerprint === before)
      return structuredClone(this.journalCache.last);
    this.journalCache = null;
    let tail = "";
    let last = null;
    try {
      for await (const chunk of createReadStream(this.journalPath, { encoding: "utf8" })) {
        const lines = (tail + chunk).split("\n");
        tail = lines.pop();
        for (const line of lines) {
          if (!line.trim()) continue;
          const entry = JSON.parse(line);
          if (entry.kind === "STATE_COMMIT") last = entry;
          else if (entry.kind === "CLOCK_CHECKPOINT") {
            if (!last || entry.fixtureId !== last.state.fixtureId ||
                entry.revision !== last.revision || last.state.clock.running !== true ||
                !Number.isSafeInteger(entry.elapsedSeconds) ||
                entry.elapsedSeconds < last.state.clock.elapsedSeconds)
              throw new Error("INVALID_JOURNAL_CLOCK_CHECKPOINT");
            last = { ...last, state: { ...last.state,
              clock: { ...last.state.clock, elapsedSeconds: entry.elapsedSeconds } } };
          }
        }
      }
    } catch (error) {
      if (error.code === "ENOENT" && before === null && await this._journalFingerprint() === null) return null;
      throw error;
    }
    if (tail.length) this.journalError = "TORN_JOURNAL_REQUIRES_REPAIR";
    const after = await this._journalFingerprint();
    if (before !== after) throw new Error('JOURNAL_CHANGED_DURING_SCAN');
    if (!tail.length && after !== null && last)
      this.journalCache = { fingerprint: after, last: structuredClone(last) };
    return last;
  }

  async load() {
    await this.init();
    // A committed journal entry is authoritative. This covers a crash between
    // durable journal append and snapshot replacement.
    const last = await this._lastCommit();
    if (last) {
      const state = hydrateMatchState(last.state);
      if (state.revision !== last.revision) throw new Error("JOURNAL_REVISION_MISMATCH");
      return state;
    }
    try {
      return hydrateMatchState(await readJson(this.snapshotPath));
    } catch (primaryError) {
      try {
        return hydrateMatchState(await readJson(this.backupPath));
      } catch {
        throw primaryError;
      }
    }
  }

  async _commit(stateLike, event, checkpoint = false) {
    await this.init();
    // Atomic directory creation coordinates independent store instances.
    // Never steal an existing lock: crash residue requires operator recovery.
    try {
      await mkdir(this.lockPath);
    } catch (error) {
      if (error.code === "EEXIST") throw new Error("WRITER_LOCK_BUSY");
      throw error;
    }
    try {
      return await this._commitLocked(stateLike, event, checkpoint);
    } finally {
      // A release failure must not negate a durable commit.
      try { await rmdir(this.lockPath); }
      catch { this.journalError = "WRITER_LOCK_RELEASE_FAILED"; }
    }
  }

  async _commitLocked(stateLike, event, checkpoint) {
    if (this.journalError) throw new Error("JOURNAL_RESTART_REQUIRED");
    await this.init();
    const state = hydrateMatchState(stateLike);
    // Never append behind a torn JSONL tail; that would create an invalid
    // complete line and make subsequent recovery fail closed.
    let lastCommit;
    try {
      lastCommit = await this._lastCommit({ useCache: true });
    } catch (error) {
      // A corrupt or concurrently changed journal cannot be trusted. Keep
      // serving only the last confirmed state and require restart/recovery.
      this.journalCache = null;
      this.journalError = "JOURNAL_SCAN_REQUIRES_RECOVERY";
      throw error;
    }
    if (this.journalError) throw new Error(this.journalError);
    if (lastCommit) {
      if (state.fixtureId !== lastCommit.state.fixtureId) throw new Error("FIXTURE_MISMATCH");
      if (checkpoint) {
        const prior = hydrateMatchState(lastCommit.state);
        if (state.revision !== prior.revision || !prior.clock.running || !state.clock.running ||
            state.clock.elapsedSeconds < prior.clock.elapsedSeconds ||
            JSON.stringify({...prior.clock, elapsedSeconds: 0}) !== JSON.stringify({...state.clock, elapsedSeconds: 0}) ||
            JSON.stringify({...prior, clock: null}) !== JSON.stringify({...state, clock: null}))
          throw new Error("INVALID_CLOCK_CHECKPOINT");
      } else {
        if (state.revision <= lastCommit.revision) throw new Error("STALE_REVISION");
        if (state.revision !== lastCommit.revision + 1) throw new Error("REVISION_GAP");
      }
    }
    if (checkpoint && !lastCommit) throw new Error("CHECKPOINT_REQUIRES_COMMIT");
    // A single fsynced record holds the complete state, including commands
    // which do not create match events (clock, score correction, etc).
    const entry = checkpoint
      ? { kind: "CLOCK_CHECKPOINT", fixtureId: state.fixtureId,
          revision: state.revision, elapsedSeconds: state.clock.elapsedSeconds }
      : { kind: "STATE_COMMIT", revision: state.revision, event, state };
    this.journalCache = null;
    let writtenFingerprint;
    try {
      const handle = await open(this.journalPath, "a");
      try {
        await handle.writeFile(JSON.stringify(entry) + "\n", "utf8");
        await handle.sync();
        // Capture the identity of the actual opened file, not a replacement path.
        const info = await handle.stat({ bigint: true });
        writtenFingerprint = [info.dev, info.ino, info.size, info.mtimeNs, info.ctimeNs].join(':');
      } finally {
        await handle.close();
      }
    } catch (error) {
      // A failed write/sync/close may still have left a complete record.
      // Refuse subsequent mutations until restart and journal recovery.
      this.journalError = error.code || "JOURNAL_WRITE_UNCERTAIN";
      throw error;
    }

    // Only reuse an immutable copy after our own durable append. Other
    // cooperative writers change the fingerprint and force a complete scan.
    // Recovery always scans; this is not a tamper-proof integrity mechanism.
    this.journalCache = { fingerprint: writtenFingerprint, last: structuredClone(
      checkpoint ? { ...lastCommit, state } : entry) };

    // Clock checkpoints are authoritative in the fsynced journal. Avoid
    // copying and serializing the entire retained match history every 15s.
    // Full command commits still refresh the compatibility snapshot.
    if (checkpoint) return state;

    // The journal is already durable. Snapshot failure must not turn a
    // committed command into an apparent failure or leave live state stale.
    const tempPath = this.snapshotPath + ".tmp";
    this.snapshotError = null;
    try {
      try {
        await copyFile(this.snapshotPath, this.backupPath);
      } catch (error) {
        if (error.code !== "ENOENT") throw error;
      }
      await writeFile(tempPath, JSON.stringify(state, null, 2), "utf8");
      await rename(tempPath, this.snapshotPath);
    } catch (error) {
      this.snapshotError = error.code || "SNAPSHOT_FAILED";
      // Never delete the previous snapshot as a fallback.
      await rm(tempPath, { force: true }).catch(() => {});
    }
    return state;
  }

  commit(stateLike, event = null) {
    const work = this.pending.then(() => this._commit(stateLike, event));
    this.pending = work.catch(() => {});
    return work;
  }

  checkpointClock(stateLike) {
    const work = this.pending.then(() => this._commit(stateLike, null, true));
    this.pending = work.catch(() => {});
    return work;
  }

  async readJournal() {
    await this.init();
    return (await this._entries()).map((entry) =>
      entry.kind === "CLOCK_CHECKPOINT" ? null : entry.kind === "STATE_COMMIT" ? entry.event : entry
    ).filter(Boolean);
  }
}
