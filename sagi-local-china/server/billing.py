import calendar
import time
from datetime import datetime, timezone
from typing import Any

from .db import connect

PLANS: dict[str, dict[str, Any]] = {
    "free": {
        "name": "免费版",
        "monthly_projects": 10,
        "monthly_ai_calls": 20,
        "storage_mb": 200,
    },
    "pro": {
        "name": "标准版",
        "monthly_projects": 200,
        "monthly_ai_calls": 500,
        "storage_mb": 5 * 1024,
    },
    "business": {
        "name": "商业版",
        "monthly_projects": 1000,
        "monthly_ai_calls": 3000,
        "storage_mb": 20 * 1024,
    },
}


def month_bounds(now: int | None = None) -> tuple[int, int]:
    ts = int(now or time.time())
    dt = datetime.fromtimestamp(ts, tz=timezone.utc)
    start = datetime(dt.year, dt.month, 1, tzinfo=timezone.utc)
    days = calendar.monthrange(dt.year, dt.month)[1]
    end = datetime(dt.year, dt.month, days, 23, 59, 59, tzinfo=timezone.utc)
    return int(start.timestamp()), int(end.timestamp())


def ensure_subscription(user_id: int) -> None:
    now = int(time.time())
    with connect() as con:
        con.execute(
            """
            INSERT INTO subscriptions(user_id,plan_code,status,expires_at,updated_at)
            VALUES(?, 'free', 'active', NULL, ?)
            ON CONFLICT(user_id) DO NOTHING
            """,
            (user_id, now),
        )


def get_subscription(user_id: int) -> dict[str, Any]:
    ensure_subscription(user_id)
    now = int(time.time())
    with connect() as con:
        row = con.execute(
            "SELECT plan_code,status,expires_at,updated_at FROM subscriptions WHERE user_id=?",
            (user_id,),
        ).fetchone()
    plan_code = (row["plan_code"] if row else "free") or "free"
    if plan_code not in PLANS:
        plan_code = "free"
    status = row["status"] if row else "active"
    expires_at = row["expires_at"] if row else None
    if expires_at and int(expires_at) < now:
        plan_code = "free"
        status = "expired"
    return {
        "plan_code": plan_code,
        "status": status,
        "expires_at": expires_at,
        "limits": PLANS[plan_code],
    }


def usage_snapshot(user_id: int) -> dict[str, Any]:
    start, end = month_bounds()
    with connect() as con:
        projects = con.execute(
            "SELECT COUNT(*) AS n FROM projects WHERE user_id=? AND created_at BETWEEN ? AND ?",
            (user_id, start, end),
        ).fetchone()["n"]
        ai_calls = con.execute(
            """
            SELECT COUNT(*) AS n FROM usage_log
            WHERE user_id=? AND created_at BETWEEN ? AND ?
              AND action IN ('copy','vision')
            """,
            (user_id, start, end),
        ).fetchone()["n"]
        storage_bytes = con.execute(
            "SELECT COALESCE(SUM(bytes),0) AS n FROM assets WHERE user_id=?",
            (user_id,),
        ).fetchone()["n"]
    return {
        "projects": int(projects),
        "ai_calls": int(ai_calls),
        "storage_bytes": int(storage_bytes),
        "period_start": start,
        "period_end": end,
    }


def quota_status(user_id: int) -> dict[str, Any]:
    subscription = get_subscription(user_id)
    usage = usage_snapshot(user_id)
    limits = subscription["limits"]
    return {
        "subscription": subscription,
        "usage": usage,
        "remaining": {
            "projects": max(0, limits["monthly_projects"] - usage["projects"]),
            "ai_calls": max(0, limits["monthly_ai_calls"] - usage["ai_calls"]),
            "storage_bytes": max(0, limits["storage_mb"] * 1024 * 1024 - usage["storage_bytes"]),
        },
    }


def can_create_project(user_id: int) -> bool:
    q = quota_status(user_id)
    return q["remaining"]["projects"] > 0


def can_use_ai(user_id: int) -> bool:
    q = quota_status(user_id)
    return q["remaining"]["ai_calls"] > 0


def can_store(user_id: int, incoming_bytes: int) -> bool:
    q = quota_status(user_id)
    return q["remaining"]["storage_bytes"] >= max(0, int(incoming_bytes))


def set_plan(user_id: int, plan_code: str, status: str = "active", expires_at: int | None = None) -> dict[str, Any]:
    if plan_code not in PLANS:
        raise ValueError("unknown plan")
    now = int(time.time())
    with connect() as con:
        con.execute(
            """
            INSERT INTO subscriptions(user_id,plan_code,status,expires_at,updated_at)
            VALUES(?,?,?,?,?)
            ON CONFLICT(user_id) DO UPDATE SET
              plan_code=excluded.plan_code,
              status=excluded.status,
              expires_at=excluded.expires_at,
              updated_at=excluded.updated_at
            """,
            (user_id, plan_code, status, expires_at, now),
        )
    return get_subscription(user_id)
