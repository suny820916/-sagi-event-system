from __future__ import annotations

import json
import mimetypes
import os
import secrets
import sqlite3
import time
import uuid
from pathlib import Path
from typing import Any

from fastapi import Depends, FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

from . import ai
from .auth import auth_user, make_token, password_hash
from .db import UPLOAD_DIR, connect, init_db

APP_VERSION = "1.4.0"
WEB_DIR = Path(__file__).resolve().parent.parent / "web"
MAX_UPLOAD_MB = max(2, min(50, int(os.getenv("MAX_UPLOAD_MB") or "12")))
MAX_UPLOAD_BYTES = MAX_UPLOAD_MB * 1024 * 1024
ALLOWED_MIME = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
}

init_db()

app = FastAPI(
    title="SAGI AI LOCAL CHINA",
    version=APP_VERSION,
)


class AuthIn(BaseModel):
    username: str = Field(min_length=3, max_length=40)
    password: str = Field(min_length=6, max_length=128)


class ProfileIn(BaseModel):
    merchant_name: str = Field(default="", max_length=80)
    industry: str = Field(default="", max_length=80)
    product: str = Field(default="", max_length=200)
    audience: str = Field(default="", max_length=200)
    brand_tone: str = Field(default="", max_length=200)
    phone: str = Field(default="", max_length=40)
    address: str = Field(default="", max_length=200)


class CopyIn(BaseModel):
    brief: str = Field(min_length=1, max_length=1200)
    style: str = Field(default="editorial", max_length=40)


class ProjectIn(BaseModel):
    title: str = Field(default="未命名海报", max_length=100)
    brief: str = Field(default="", max_length=1200)
    style: str = Field(default="editorial", max_length=40)
    source_asset_id: str | None = None
    poster34_asset_id: str | None = None
    poster916_asset_id: str | None = None
    metadata: dict[str, Any] = Field(default_factory=dict)


def profile_for(user_id: int) -> dict[str, Any]:
    with connect() as con:
        row = con.execute(
            "SELECT * FROM profiles WHERE user_id=?",
            (user_id,),
        ).fetchone()
    return dict(row) if row else {}


def record_usage(user_id: int, action: str, engine: str) -> None:
    with connect() as con:
        con.execute(
            "INSERT INTO usage_log(user_id,action,engine,created_at) VALUES(?,?,?,?)",
            (user_id, action[:40], engine[:40], int(time.time())),
        )


@app.get("/health")
def health() -> dict[str, Any]:
    return {
        "ok": True,
        "service": "SAGI AI LOCAL CHINA",
        "version": APP_VERSION,
        "chinaDeploy": True,
        "sameOrigin": True,
        "basePosterWorksWithoutAI": True,
        "aiConfigured": ai.configured(),
        "visionConfigured": ai.vision_configured(),
        "maxUploadMB": MAX_UPLOAD_MB,
    }


@app.post("/api/auth/register")
def register(body: AuthIn) -> dict[str, Any]:
    username = body.username.strip().lower()
    salt = secrets.token_hex(16)
    ph = password_hash(body.password, salt)
    now = int(time.time())
    try:
        with connect() as con:
            cur = con.execute(
                "INSERT INTO users(username,password_hash,salt,created_at) VALUES(?,?,?,?)",
                (username, ph, salt, now),
            )
            uid = int(cur.lastrowid)
            con.execute(
                "INSERT INTO profiles(user_id,updated_at) VALUES(?,?)",
                (uid, now),
            )
    except sqlite3.IntegrityError as exc:
        raise HTTPException(status_code=409, detail="该账号已存在") from exc
    return {
        "ok": True,
        "token": make_token(uid),
        "user": {"id": uid, "username": username},
    }


@app.post("/api/auth/login")
def login(body: AuthIn) -> dict[str, Any]:
    username = body.username.strip().lower()
    with connect() as con:
        row = con.execute(
            "SELECT id,username,password_hash,salt FROM users WHERE username=?",
            (username,),
        ).fetchone()
    if not row:
        raise HTTPException(status_code=401, detail="账号或密码不正确")
    candidate = password_hash(body.password, row["salt"])
    if not secrets.compare_digest(candidate, row["password_hash"]):
        raise HTTPException(status_code=401, detail="账号或密码不正确")
    return {
        "ok": True,
        "token": make_token(int(row["id"])),
        "user": {"id": row["id"], "username": row["username"]},
    }


@app.get("/api/me")
def me(user=Depends(auth_user)) -> dict[str, Any]:
    return {"ok": True, "user": user}


@app.get("/api/profile")
def get_profile(user=Depends(auth_user)) -> dict[str, Any]:
    return {"ok": True, "profile": profile_for(user["id"])}


@app.put("/api/profile")
def put_profile(body: ProfileIn, user=Depends(auth_user)) -> dict[str, Any]:
    with connect() as con:
        con.execute(
            """
            UPDATE profiles
            SET merchant_name=?,industry=?,product=?,audience=?,brand_tone=?,
                phone=?,address=?,updated_at=?
            WHERE user_id=?
            """,
            (
                body.merchant_name.strip(),
                body.industry.strip(),
                body.product.strip(),
                body.audience.strip(),
                body.brand_tone.strip(),
                body.phone.strip(),
                body.address.strip(),
                int(time.time()),
                user["id"],
            ),
        )
    return {"ok": True}


@app.post("/api/assets")
async def upload_asset(
    kind: str = Form(default="source"),
    file: UploadFile = File(...),
    user=Depends(auth_user),
) -> dict[str, Any]:
    mime = (file.content_type or "").split(";", 1)[0].lower()
    if mime not in ALLOWED_MIME:
        raise HTTPException(status_code=415, detail="只支持 JPG / PNG / WebP")

    raw = await file.read(MAX_UPLOAD_BYTES + 1)
    if not raw:
        raise HTTPException(status_code=400, detail="图片为空")
    if len(raw) > MAX_UPLOAD_BYTES:
        raise HTTPException(
            status_code=413,
            detail="图片不能超过 " + str(MAX_UPLOAD_MB) + "MB",
        )

    asset_id = uuid.uuid4().hex
    stored_name = asset_id + ALLOWED_MIME[mime]
    (UPLOAD_DIR / stored_name).write_bytes(raw)
    now = int(time.time())

    with connect() as con:
        con.execute(
            """
            INSERT INTO assets(
                id,user_id,kind,filename,stored_name,mime,bytes,created_at
            ) VALUES(?,?,?,?,?,?,?,?)
            """,
            (
                asset_id,
                user["id"],
                kind[:32],
                file.filename or stored_name,
                stored_name,
                mime,
                len(raw),
                now,
            ),
        )

    return {
        "ok": True,
        "asset": {
            "id": asset_id,
            "kind": kind,
            "mime": mime,
            "bytes": len(raw),
            "url": "/api/assets/" + asset_id,
        },
    }


@app.get("/api/assets/{asset_id}")
def get_asset(asset_id: str, user=Depends(auth_user)):
    with connect() as con:
        row = con.execute(
            "SELECT * FROM assets WHERE id=? AND user_id=?",
            (asset_id, user["id"]),
        ).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="图片不存在")

    path = UPLOAD_DIR / row["stored_name"]
    if not path.exists():
        raise HTTPException(status_code=404, detail="图片文件不存在")

    return FileResponse(
        path,
        media_type=row["mime"],
        filename=row["filename"],
    )


@app.post("/api/ai/copy")
async def ai_copy(body: CopyIn, user=Depends(auth_user)) -> dict[str, Any]:
    profile = profile_for(user["id"])
    result = await ai.generate_copy(body.brief, body.style, profile)
    record_usage(user["id"], "copy", result.get("engine", "unknown"))
    return {"ok": True, "copy": result}


@app.post("/api/ai/vision")
async def ai_vision(
    brief: str = Form(default=""),
    image: UploadFile = File(...),
    user=Depends(auth_user),
) -> dict[str, Any]:
    mime = (image.content_type or "").split(";", 1)[0].lower()
    if mime not in ALLOWED_MIME:
        raise HTTPException(status_code=415, detail="只支持 JPG / PNG / WebP")

    raw = await image.read(MAX_UPLOAD_BYTES + 1)
    if not raw:
        raise HTTPException(status_code=400, detail="图片为空")
    if len(raw) > MAX_UPLOAD_BYTES:
        raise HTTPException(
            status_code=413,
            detail="图片不能超过 " + str(MAX_UPLOAD_MB) + "MB",
        )

    result = await ai.analyze_image(
        raw,
        mime,
        brief,
        profile_for(user["id"]),
    )
    record_usage(user["id"], "vision", result.get("engine", "unknown"))
    return {"ok": True, "visual": result}


@app.post("/api/projects")
def create_project(body: ProjectIn, user=Depends(auth_user)) -> dict[str, Any]:
    project_id = uuid.uuid4().hex
    now = int(time.time())

    asset_ids = [
        body.source_asset_id,
        body.poster34_asset_id,
        body.poster916_asset_id,
    ]
    with connect() as con:
        for asset_id in [x for x in asset_ids if x]:
            found = con.execute(
                "SELECT id FROM assets WHERE id=? AND user_id=?",
                (asset_id, user["id"]),
            ).fetchone()
            if not found:
                raise HTTPException(status_code=400, detail="项目包含无效图片")

        con.execute(
            """
            INSERT INTO projects(
                id,user_id,title,brief,style,source_asset_id,
                poster34_asset_id,poster916_asset_id,metadata_json,created_at
            ) VALUES(?,?,?,?,?,?,?,?,?,?)
            """,
            (
                project_id,
                user["id"],
                body.title,
                body.brief,
                body.style,
                body.source_asset_id,
                body.poster34_asset_id,
                body.poster916_asset_id,
                json.dumps(body.metadata, ensure_ascii=False),
                now,
            ),
        )

    return {
        "ok": True,
        "project": {"id": project_id, "created_at": now},
    }


@app.get("/api/projects")
def list_projects(user=Depends(auth_user)) -> dict[str, Any]:
    with connect() as con:
        rows = con.execute(
            """
            SELECT id,title,brief,style,source_asset_id,poster34_asset_id,
                   poster916_asset_id,metadata_json,created_at
            FROM projects
            WHERE user_id=?
            ORDER BY created_at DESC
            LIMIT 100
            """,
            (user["id"],),
        ).fetchall()

    items = []
    for row in rows:
        item = dict(row)
        raw_meta = item.pop("metadata_json", "{}")
        try:
            item["metadata"] = json.loads(raw_meta)
        except Exception:
            item["metadata"] = {}
        items.append(item)

    return {"ok": True, "projects": items}


@app.get("/api/usage")
def usage(user=Depends(auth_user)) -> dict[str, Any]:
    cutoff = int(time.time()) - 31 * 24 * 3600
    with connect() as con:
        rows = con.execute(
            """
            SELECT action,engine,COUNT(*) AS count
            FROM usage_log
            WHERE user_id=? AND created_at>=?
            GROUP BY action,engine
            ORDER BY action,engine
            """,
            (user["id"], cutoff),
        ).fetchall()
    return {"ok": True, "usage": [dict(row) for row in rows]}


if WEB_DIR.exists():
    app.mount("/", StaticFiles(directory=WEB_DIR, html=True), name="web")
