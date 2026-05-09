import asyncio
import json
import os
import re
import time
from typing import Any

import gdown
import httpx
from google import genai
from google.genai import types as genai_types

from env_config import load_project_env


load_project_env()

DEFAULT_PRODUCT_IMAGE_FOLDER_URL = (
    "https://drive.google.com/drive/folders/"
    "1FZJ2DPHDyj3aVFUY8ylL2HVRG04sbCc2?usp=sharing"
)
PRODUCT_IMAGE_FOLDER_URL = (
    os.getenv("MILA_PRODUCT_IMAGE_FOLDER_URL", DEFAULT_PRODUCT_IMAGE_FOLDER_URL).strip()
    or DEFAULT_PRODUCT_IMAGE_FOLDER_URL
)
PRODUCT_IMAGE_CACHE_TTL_SECONDS = max(
    30,
    int(os.getenv("MILA_PRODUCT_IMAGE_CACHE_TTL_SECONDS", "300").strip() or "300"),
)
PRODUCT_IMAGE_HTTP_TIMEOUT_SECONDS = float(
    os.getenv("MILA_PRODUCT_IMAGE_HTTP_TIMEOUT_SECONDS", "30").strip() or "30"
)
PRODUCT_IMAGE_OCR_MODEL = (
    os.getenv("MILA_PRODUCT_IMAGE_OCR_MODEL", "gemini-2.5-flash").strip()
    or "gemini-2.5-flash"
)
PRODUCT_IMAGE_OCR_MAX_IMAGES_PER_SEARCH = max(
    1,
    int(os.getenv("MILA_PRODUCT_IMAGE_OCR_MAX_IMAGES_PER_SEARCH", "12").strip() or "12"),
)
PRODUCT_IMAGE_OCR_ENABLED = (
    os.getenv("MILA_PRODUCT_IMAGE_OCR_ENABLED", "true").strip().lower()
    in {"1", "true", "yes", "on"}
)
GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY", "").strip()

_CACHE_ITEMS: list[dict[str, Any]] | None = None
_CACHE_LOADED_AT_TS: float = 0.0
_OCR_BY_FILE_ID: dict[str, str] = {}
_OCR_INDEXED_AT_TS: dict[str, float] = {}


def _extract_model_candidates(text: str) -> list[str]:
    # Common model code patterns like V-17037, v-795, HM-11502.
    matches = re.findall(r"\b[A-Za-z]{1,3}-?\d{2,6}\b", text)
    normalized: list[str] = []
    for value in matches:
        code = value.upper().replace(" ", "")
        if code not in normalized:
            normalized.append(code)
    return normalized


def _extract_price_candidates(text: str) -> list[str]:
    matches = re.findall(r"\b\d{1,5}(?:[.,]\d{1,2})?\s?(?:\$|USD|UZS|сум)?\b", text)
    unique: list[str] = []
    for value in matches:
        normalized = value.strip()
        if normalized and normalized not in unique:
            unique.append(normalized)
    return unique


def _is_image_path(path: str) -> bool:
    lower = path.lower()
    return lower.endswith((".jpg", ".jpeg", ".png", ".webp", ".bmp"))


def _to_direct_image_url(file_id: str) -> str:
    return f"https://drive.google.com/uc?export=download&id={file_id}"


def _to_preview_image_url(file_id: str) -> str:
    return f"https://lh3.googleusercontent.com/d/{file_id}=w1600"


def _build_haystack(row: dict[str, Any]) -> str:
    return " ".join(
        [
            row.get("path", ""),
            row.get("file_name", ""),
            row.get("file_id", ""),
            " ".join(row.get("model_candidates", [])),
            " ".join(row.get("price_candidates", [])),
            row.get("ocr_text", ""),
        ]
    ).lower()


def _looks_like_model_or_price_query(term: str) -> bool:
    return bool(
        re.search(r"[A-Za-z]-?\d{2,6}", term)
        or re.search(r"\b\d{1,5}(?:[.,]\d{1,2})?\b", term)
        or any(token in term for token in ("model", "модел", "цена", "price", "narx"))
    )


def _run_image_ocr_sync(image_bytes: bytes) -> str:
    if not GOOGLE_API_KEY:
        return ""

    client = genai.Client(api_key=GOOGLE_API_KEY)
    prompt = (
        "Extract visible product info from this catalog image. "
        "Return plain text lines with model codes and prices only. "
        "If none are visible, return empty."
    )
    response = client.models.generate_content(
        model=PRODUCT_IMAGE_OCR_MODEL,
        contents=[
            prompt,
            genai_types.Part.from_bytes(data=image_bytes, mime_type="image/jpeg"),
        ],
    )
    return (response.text or "").strip()


async def _load_image_catalog_items() -> list[dict[str, Any]]:
    file_items = gdown.download_folder(
        url=PRODUCT_IMAGE_FOLDER_URL,
        skip_download=True,
        quiet=True,
        use_cookies=False,
        remaining_ok=True,
    )
    if not file_items:
        return []

    items: list[dict[str, Any]] = []
    for index, file_item in enumerate(file_items, start=1):
        path = file_item.path or ""
        if not _is_image_path(path):
            continue

        basename = os.path.basename(path)
        model_candidates = _extract_model_candidates(path)
        price_candidates = _extract_price_candidates(path)
        items.append(
            {
                "index": index,
                "file_id": file_item.id,
                "path": path,
                "file_name": basename,
                "direct_image_url": _to_direct_image_url(file_item.id),
                "preview_image_url": _to_preview_image_url(file_item.id),
                "model_candidates": model_candidates,
                "price_candidates": price_candidates,
                "ocr_text": "",
            }
        )

    return items


async def _get_catalog_items(force_refresh: bool = False) -> list[dict[str, Any]]:
    global _CACHE_ITEMS, _CACHE_LOADED_AT_TS

    now = time.time()
    is_fresh = (
        not force_refresh
        and _CACHE_ITEMS is not None
        and (now - _CACHE_LOADED_AT_TS) < PRODUCT_IMAGE_CACHE_TTL_SECONDS
    )
    if is_fresh:
        return _CACHE_ITEMS

    items = await _load_image_catalog_items()
    _CACHE_ITEMS = items
    _CACHE_LOADED_AT_TS = now
    return items


async def _ocr_one_item(row: dict[str, Any]) -> str:
    file_id = row.get("file_id", "")
    if not file_id:
        return ""

    cached = _OCR_BY_FILE_ID.get(file_id)
    if cached is not None:
        return cached

    try:
        async with httpx.AsyncClient(
            timeout=PRODUCT_IMAGE_HTTP_TIMEOUT_SECONDS,
            follow_redirects=True,
        ) as client:
            response = await client.get(row["direct_image_url"])
        response.raise_for_status()
        image_bytes = response.content
        ocr_text = await asyncio.to_thread(_run_image_ocr_sync, image_bytes)
    except Exception:
        ocr_text = ""

    _OCR_BY_FILE_ID[file_id] = ocr_text
    _OCR_INDEXED_AT_TS[file_id] = time.time()
    if ocr_text:
        row["ocr_text"] = ocr_text
        row["model_candidates"] = sorted(
            set(row.get("model_candidates", []) + _extract_model_candidates(ocr_text))
        )
        row["price_candidates"] = sorted(
            set(row.get("price_candidates", []) + _extract_price_candidates(ocr_text))
        )
    return ocr_text


async def _ensure_ocr_for_search(
    items: list[dict[str, Any]],
    max_images_to_scan: int,
    search_term: str,
) -> int:
    if not PRODUCT_IMAGE_OCR_ENABLED or not GOOGLE_API_KEY:
        return 0

    scanned = 0
    for row in items:
        if scanned >= max_images_to_scan:
            break
        file_id = row.get("file_id", "")
        if not file_id:
            continue
        if file_id in _OCR_BY_FILE_ID:
            continue
        await _ocr_one_item(row)
        scanned += 1
        if search_term and search_term in _build_haystack(row):
            break
    return scanned


async def get_product_image_catalog_status(force_refresh: bool = False) -> str:
    items = await _get_catalog_items(force_refresh=force_refresh)
    payload = {
        "configured_folder_url": PRODUCT_IMAGE_FOLDER_URL,
        "cache_ttl_seconds": PRODUCT_IMAGE_CACHE_TTL_SECONDS,
        "ocr_enabled": PRODUCT_IMAGE_OCR_ENABLED and bool(GOOGLE_API_KEY),
        "ocr_model": PRODUCT_IMAGE_OCR_MODEL,
        "ocr_indexed_images": len(_OCR_BY_FILE_ID),
        "total_images": len(items),
    }
    return json.dumps(payload, ensure_ascii=False, indent=2)


async def list_product_image_catalog(limit: int = 30, force_refresh: bool = False) -> str:
    items = await _get_catalog_items(force_refresh=force_refresh)
    bounded_limit = max(1, min(int(limit), 300))
    payload = {
        "configured_folder_url": PRODUCT_IMAGE_FOLDER_URL,
        "count": len(items),
        "items": items[:bounded_limit],
    }
    return json.dumps(payload, ensure_ascii=False, indent=2)


async def search_product_image_catalog(
    query: str,
    limit: int = 30,
    force_refresh: bool = False,
    max_ocr_images: int | None = None,
) -> str:
    term = query.strip().lower()
    if not term:
        return "Search query is empty."

    items = await _get_catalog_items(force_refresh=force_refresh)
    matches = [row for row in items if term in _build_haystack(row)]

    # If nothing found and query looks like product/model/price, OCR-scan part of catalog.
    ocr_scanned = 0
    if not matches and _looks_like_model_or_price_query(term):
        scan_budget = PRODUCT_IMAGE_OCR_MAX_IMAGES_PER_SEARCH
        if max_ocr_images is not None:
            scan_budget = max(1, min(int(max_ocr_images), len(items)))
        ocr_scanned = await _ensure_ocr_for_search(
            items,
            max_images_to_scan=scan_budget,
            search_term=term,
        )
        matches = [row for row in items if term in _build_haystack(row)]

    bounded_limit = max(1, min(int(limit), 300))
    payload = {
        "configured_folder_url": PRODUCT_IMAGE_FOLDER_URL,
        "query": query,
        "count": len(matches),
        "ocr_scanned_images_this_call": ocr_scanned,
        "items": matches[:bounded_limit],
    }
    return json.dumps(payload, ensure_ascii=False, indent=2)
