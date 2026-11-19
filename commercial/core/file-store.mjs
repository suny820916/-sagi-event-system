import {
  appendFile,
  copyFile,
  mkdir,
  readFile,
  rename,
  rm,
  writeFile,
} from "node:fs/promises";
import path from "node:path";
import { hydrateMatchState } from "./match-core.mjs";

async function readJson(file) {
  const text = await readFile(file, "utf8");
  return JSON.parse(text);
}

export class FileMatchStore {
  constructor(rootDir) {
    if (!rootDir) throw new Error("ROOT_DIR_REQUIRED");
    this.rootDir = rootDir;
    this.snapshotPath = path.join(rootDir, "match-state.json");
    this.backupPath = path.join(rootDir, "match-state.bak.json");
    this.journalPath = path.join(rootDir, "match-events.jsonl");
  }

  async init() {
    await mkdir(this.rootDir, { recursive: true });
    return this;
  }

  async load() {
    await this.init();
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

  async commit(stateLike, event = null) {
    await this.init();
    const state = hydrateMatchState(stateLike);

    // Journal first: if the process dies after this append, the event is still auditable.
    if (event) {
      await appendFile(this.journalPath, JSON.stringify(event) + "\n", "utf8");
    }

    const tempPath = this.snapshotPath + ".tmp";
    try {
      await copyFile(this.snapshotPath, this.backupPath);
    } catch {
      // First commit has no previous snapshot.
    }

    await writeFile(tempPath, JSON.stringify(state, null, 2), "utf8");

    try {
      await rename(tempPath, this.snapshotPath);
    } catch (error) {
      // Some Windows environments reject rename over an existing destination.
      // Remove only after a complete temp snapshot exists.
      await rm(this.snapshotPath, { force: true });
      await rename(tempPath, this.snapshotPath);
    }

    return state;
  }

  async readJournal() {
    await this.init();
    try {
      const text = await readFile(this.journalPath, "utf8");
      return text
        .split(/\r?\n/)
        .filter(Boolean)
        .map((line) => JSON.parse(line));
    } catch {
      return [];
    }
  }
}
