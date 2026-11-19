import { copyFile, mkdir, open, readFile, rename, rm, writeFile } from "node:fs/promises";
import path from "node:path";
import { hydrateMatchState } from "./match-core.mjs";

async function readJson(file) {
  return JSON.parse(await readFile(file, "utf8"));
}

function parseJournal(text) {
  const lines = text.split("\n");
  const complete = text.endsWith("\n") ? lines.slice(0, -1) : lines.slice(0, -1);
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
    this.pending = Promise.resolve();
  }

  async init() {
    await mkdir(this.rootDir, { recursive: true });
    return this;
  }

  async _entries() {
    try {
      return parseJournal(await readFile(this.journalPath, "utf8"));
    } catch (error) {
      if (error.code === "ENOENT") return [];
      throw error;
    }
  }

  async load() {
    await this.init();
    // A committed journal entry is authoritative. This covers a crash between
    // durable journal append and snapshot replacement.
    const entries = await this._entries();
    const committed = entries.filter((entry) => entry.kind === "STATE_COMMIT");
    if (committed.length) {
      const last = committed.at(-1);
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

  async _commit(stateLike, event) {
    await this.init();
    const state = hydrateMatchState(stateLike);
    const entries = await this._entries();
    const lastCommit = [...entries].reverse().find((entry) => entry.kind === "STATE_COMMIT");
    if (lastCommit) {
      if (state.fixtureId !== lastCommit.state.fixtureId) throw new Error("FIXTURE_MISMATCH");
      if (state.revision <= lastCommit.revision) throw new Error("STALE_REVISION");
      if (state.revision !== lastCommit.revision + 1) throw new Error("REVISION_GAP");
    }
    // A single fsynced record holds the complete state, including commands
    // which do not create match events (clock, score correction, etc).
    const entry = { kind: "STATE_COMMIT", revision: state.revision, event, state };
    const handle = await open(this.journalPath, "a");
    try {
      await handle.writeFile(JSON.stringify(entry) + "\n", "utf8");
      await handle.sync();
    } finally {
      await handle.close();
    }

    const tempPath = this.snapshotPath + ".tmp";
    try {
      await copyFile(this.snapshotPath, this.backupPath);
    } catch (error) {
      if (error.code !== "ENOENT") throw error;
    }
    await writeFile(tempPath, JSON.stringify(state, null, 2), "utf8");
    try {
      await rename(tempPath, this.snapshotPath);
    } catch (error) {
      // Windows may not allow overwrite rename. Journal remains authoritative.
      await rm(this.snapshotPath, { force: true });
      await rename(tempPath, this.snapshotPath);
    }
    return state;
  }

  commit(stateLike, event = null) {
    const work = this.pending.then(() => this._commit(stateLike, event));
    this.pending = work.catch(() => {});
    return work;
  }

  async readJournal() {
    await this.init();
    return (await this._entries()).map((entry) =>
      entry.kind === "STATE_COMMIT" ? entry.event : entry
    ).filter(Boolean);
  }
}
