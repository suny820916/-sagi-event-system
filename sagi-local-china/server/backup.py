from __future__ import annotations

import os
import shutil
import sqlite3
import tarfile
import time
from pathlib import Path

from .db import DATA_DIR, DB_PATH, UPLOAD_DIR

BACKUP_DIR = DATA_DIR / "backups"
RETENTION_DAYS = max(1, min(90, int(os.getenv("BACKUP_RETENTION_DAYS") or "14")))


def backup_once() -> Path:
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%d-%H%M%S", time.localtime())
    work = BACKUP_DIR / ("work-" + stamp)
    work.mkdir(parents=True, exist_ok=True)

    db_copy = work / "sagi_local_china.db"
    source = sqlite3.connect(DB_PATH)
    target = sqlite3.connect(db_copy)
    with target:
        source.backup(target)
    target.close()
    source.close()

    if UPLOAD_DIR.exists():
        shutil.copytree(UPLOAD_DIR, work / "uploads", dirs_exist_ok=True)

    archive = BACKUP_DIR / ("sagi-local-china-" + stamp + ".tar.gz")
    with tarfile.open(archive, "w:gz") as tar:
        tar.add(work, arcname="sagi-local-china")
    shutil.rmtree(work, ignore_errors=True)

    cutoff = time.time() - RETENTION_DAYS * 86400
    for p in BACKUP_DIR.glob("sagi-local-china-*.tar.gz"):
        try:
            if p.stat().st_mtime < cutoff:
                p.unlink()
        except OSError:
            pass
    return archive


if __name__ == "__main__":
    path = backup_once()
    print(path)
