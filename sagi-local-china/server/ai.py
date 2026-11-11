import base64
import json
import os
from typing import Any

import httpx

AI_BASE_URL = (os.getenv("AI_BASE_URL") or "").rstrip("/")
AI_API_KEY = os.getenv("AI_API_KEY") or ""
AI_MODEL = os.getenv("AI_MODEL") or ""
AI_VISION_MODEL = os.getenv("AI_VISION_MODEL") or AI_MODEL
AI_TIMEOUT = max(10, min(90, int(os.getenv("AI_TIMEOUT_SECONDS") or "35")))


def configured() -> bool:
    return bool(AI_BASE_URL and AI_API_KEY and AI_MODEL)


def vision_configured() -> bool:
    return bool(AI_BASE_URL and AI_API_KEY and AI_VISION_MODEL)


def _chat_url() -> str:
    base = AI_BASE_URL
    if not base.endswith("/v1"):
        base += "/v1"
    return base + "/chat/completions"


def extract_json(text: str) -> dict[str, Any]:
    clean = (text or "").strip()
    fence = chr(96) * 3
    if clean.startswith(fence):
        clean = clean.split("\n", 1)[1] if "\n" in clean else clean
        clean = clean.rsplit(fence, 1)[0].strip()
        if clean.startswith("json"):
            clean = clean[4:].strip()
    return json.loads(clean)


async def chat(messages: list[dict[str, Any]], model: str) -> str:
    if not (AI_BASE_URL and AI_API_KEY and model):
        raise RuntimeError("AI not configured")
    body = {
        "model": model,
        "messages": messages,
        "temperature": 0.65,
        "max_tokens": 1400,
    }
    async with httpx.AsyncClient(timeout=AI_TIMEOUT) as client:
        response = await client.post(
            _chat_url(),
            headers={
                "Authorization": "Bearer " + AI_API_KEY,
                "Content-Type": "application/json",
            },
            json=body,
        )
        response.raise_for_status()
        data = response.json()
        return data["choices"][0]["message"]["content"]


def local_copy(brief: str, profile: dict[str, Any]) -> dict[str, Any]:
    merchant = profile.get("merchant_name") or "本店"
    product = profile.get("product") or "今日主推"
    headline = (brief.strip() or product)[:18]
    subheadline = product[:26] if product != headline else "真实产品 · 真实场景"
    return {
        "headline": headline,
        "subheadline": subheadline,
        "cta": "立即了解",
        "douyin": headline + "\n\n" + brief + "\n#" + merchant.replace(" ", "") + " #本地生活",
        "moments": brief + "\n\n" + merchant + "｜欢迎到店 / 私信咨询",
        "engine": "local-fallback",
    }


async def generate_copy(brief: str, style: str, profile: dict[str, Any]) -> dict[str, Any]:
    fallback = local_copy(brief, profile)
    if not configured():
        return fallback

    instruction = {
        "merchant": profile,
        "brief": brief,
        "style": style,
        "rules": [
            "只使用商家明确提供的信息",
            "不编造价格、折扣、销量、评价、奖项",
            "标题18个汉字以内",
            "副标题26个汉字以内",
            "CTA 10个汉字以内",
            "返回JSON对象，字段 headline, subheadline, cta, douyin, moments",
            "中文自然，像真实本地商家，不要AI套话",
        ],
    }
    try:
        raw = await chat(
            [
                {
                    "role": "system",
                    "content": "你是SAGI AI LOCAL的本地商业内容导演，只返回JSON。",
                },
                {
                    "role": "user",
                    "content": json.dumps(instruction, ensure_ascii=False),
                },
            ],
            AI_MODEL,
        )
        parsed = extract_json(raw)
        result = fallback.copy()
        for key in ("headline", "subheadline", "cta", "douyin", "moments"):
            if parsed.get(key):
                result[key] = str(parsed[key])
        result["engine"] = "ai"
        return result
    except Exception:
        return fallback


async def analyze_image(
    raw: bytes,
    mime: str,
    brief: str,
    profile: dict[str, Any],
) -> dict[str, Any]:
    fallback = {
        "subject": "商家上传的真实照片",
        "scene": "本地商业宣传场景",
        "cropFocus": "center",
        "overlayPosition": "bottom",
        "strengths": ["保留真实素材，可信度高"],
        "fixes": ["优先保证主体完整，并给标题留出干净空间"],
        "engine": "local-fallback",
    }
    if not vision_configured():
        return fallback

    data_url = "data:" + mime + ";base64," + base64.b64encode(raw).decode("ascii")
    instruction = {
        "merchant": profile,
        "brief": brief,
        "output": {
            "subject": "简短描述主体",
            "scene": "简短描述场景",
            "cropFocus": "center|top|bottom|left|right",
            "overlayPosition": "top|bottom|left|right",
            "strengths": ["2-3条视觉优势"],
            "fixes": ["1-3条可执行改进"],
        },
        "rules": [
            "不要识别人脸身份",
            "不要推断敏感属性",
            "不要编造价格、销量或评价",
            "只返回JSON",
        ],
    }
    try:
        raw_text = await chat(
            [
                {
                    "role": "system",
                    "content": "你是商业视觉导演，只返回JSON。",
                },
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": json.dumps(instruction, ensure_ascii=False),
                        },
                        {
                            "type": "image_url",
                            "image_url": {"url": data_url},
                        },
                    ],
                },
            ],
            AI_VISION_MODEL,
        )
        parsed = extract_json(raw_text)
        result = fallback.copy()
        result.update(parsed)
        result["engine"] = "ai"
        return result
    except Exception:
        return fallback
