import hmac
import os

from fastapi import Header, HTTPException

ADMIN_KEY = os.getenv("SAGI_ADMIN_KEY") or ""


def admin_auth(x_admin_key: str | None = Header(default=None)) -> bool:
    if not ADMIN_KEY:
        raise HTTPException(status_code=503, detail="管理员密钥未配置")
    if not x_admin_key or not hmac.compare_digest(x_admin_key, ADMIN_KEY):
        raise HTTPException(status_code=401, detail="管理员认证失败")
    return True
