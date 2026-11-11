import base64
import hashlib
import hmac
import json
import os
import time

from fastapi import Header, HTTPException

from .db import connect

SECRET = (os.getenv("SAGI_SECRET") or "dev-only-change-me").encode("utf-8")


def _b64url(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")


def _b64url_decode(value: str) -> bytes:
    return base64.urlsafe_b64decode(value + "=" * (-len(value) % 4))


def make_token(user_id: int, ttl_seconds: int = 60 * 60 * 24 * 30) -> str:
    payload = {"uid": user_id, "exp": int(time.time()) + ttl_seconds}
    body = _b64url(json.dumps(payload, separators=(",", ":")).encode("utf-8"))
    sig = _b64url(hmac.new(SECRET, body.encode("ascii"), hashlib.sha256).digest())
    return body + "." + sig


def read_token(token: str) -> int:
    try:
        body, sig = token.split(".", 1)
        expected = _b64url(hmac.new(SECRET, body.encode("ascii"), hashlib.sha256).digest())
        if not hmac.compare_digest(sig, expected):
            raise ValueError("bad signature")
        payload = json.loads(_b64url_decode(body))
        if int(payload["exp"]) < int(time.time()):
            raise ValueError("expired")
        return int(payload["uid"])
    except Exception as exc:
        raise HTTPException(status_code=401, detail="登录已失效，请重新登录") from exc


def password_hash(password: str, salt_hex: str) -> str:
    return hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        bytes.fromhex(salt_hex),
        180_000,
    ).hex()


def auth_user(authorization: str | None = Header(default=None)) -> dict:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="请先登录")
    uid = read_token(authorization.split(" ", 1)[1].strip())
    with connect() as con:
        row = con.execute(
            "SELECT id,username,created_at FROM users WHERE id=?",
            (uid,),
        ).fetchone()
    if not row:
        raise HTTPException(status_code=401, detail="用户不存在")
    return dict(row)
