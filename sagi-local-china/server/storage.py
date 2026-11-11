from __future__ import annotations

import os
from pathlib import Path

from .db import UPLOAD_DIR

STORAGE_BACKEND = (os.getenv("STORAGE_BACKEND") or "local").strip().lower()
S3_ENDPOINT_URL = (os.getenv("S3_ENDPOINT_URL") or "").strip() or None
S3_REGION = (os.getenv("S3_REGION") or "").strip() or None
S3_BUCKET = (os.getenv("S3_BUCKET") or "").strip()
S3_ACCESS_KEY = (os.getenv("S3_ACCESS_KEY") or "").strip()
S3_SECRET_KEY = (os.getenv("S3_SECRET_KEY") or "").strip()


def backend() -> str:
    return STORAGE_BACKEND


def _client():
    if STORAGE_BACKEND != "s3":
        return None
    if not (S3_BUCKET and S3_ACCESS_KEY and S3_SECRET_KEY):
        raise RuntimeError("S3 storage is selected but credentials/bucket are incomplete")
    import boto3

    return boto3.client(
        "s3",
        endpoint_url=S3_ENDPOINT_URL,
        region_name=S3_REGION,
        aws_access_key_id=S3_ACCESS_KEY,
        aws_secret_access_key=S3_SECRET_KEY,
    )


def save(name: str, raw: bytes, mime: str) -> None:
    if STORAGE_BACKEND == "s3":
        _client().put_object(
            Bucket=S3_BUCKET,
            Key="assets/" + name,
            Body=raw,
            ContentType=mime,
        )
        return
    path = UPLOAD_DIR / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(raw)


def local_path(name: str) -> Path | None:
    if STORAGE_BACKEND != "local":
        return None
    return UPLOAD_DIR / name


def exists(name: str) -> bool:
    if STORAGE_BACKEND == "s3":
        try:
            _client().head_object(Bucket=S3_BUCKET, Key="assets/" + name)
            return True
        except Exception:
            return False
    return (UPLOAD_DIR / name).exists()


def signed_url(name: str, filename: str | None = None, expires: int = 900) -> str:
    if STORAGE_BACKEND != "s3":
        raise RuntimeError("signed_url only applies to s3 backend")
    params = {"Bucket": S3_BUCKET, "Key": "assets/" + name}
    if filename:
        params["ResponseContentDisposition"] = 'inline; filename="' + filename.replace('"', "") + '"'
    return _client().generate_presigned_url(
        "get_object",
        Params=params,
        ExpiresIn=max(60, min(3600, int(expires))),
    )
