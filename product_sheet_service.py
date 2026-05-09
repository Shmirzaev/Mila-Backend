import csv
import io
import json
import os
import re
import time
from typing import Any
from urllib.parse import parse_qs, urlparse

import httpx

from env_config import load_project_env


load_project_env()

DEFAULT_PRODUCT_SHEET_URL = (
    "https://docs.google.com/spreadsheets/d/"
    "18x-ak239qEZxlua1whytB-ijZHiDcHrh/edit?gid=1140905256#gid=1140905256"
)
PRODUCT_SHEET_URL = (
    os.getenv("MILA_PRODUCT_SHEET_URL", DEFAULT_PRODUCT_SHEET_URL).strip()
    or DEFAULT_PRODUCT_SHEET_URL
)
PRODUCT_SHEET_TIMEOUT_SECONDS = float(
    os.getenv("MILA_PRODUCT_SHEET_TIMEOUT_SECONDS", "20").strip() or "20"
)
PRODUCT_SHEET_CACHE_TTL_SECONDS = max(
    5,
    int(os.getenv("MILA_PRODUCT_SHEET_CACHE_TTL_SECONDS", "60").strip() or "60"),
)

_CACHE_ROWS: list[dict[str, Any]] | None = None
_CACHE_HEADERS: list[str] = []
_CACHE_SOURCE_URL: str = ""
_CACHE_LOADED_AT_TS: float = 0.0


def _norm_key(value: str | None) -> str:
    return re.sub(r"\s+", "", (value or "").strip().lower())


def _build_export_url(sheet_url: str) -> str:
    parsed = urlparse(sheet_url)
    host = parsed.netloc.lower()

    if "docs.google.com" not in host:
        return sheet_url

    sheet_id_match = re.search(r"/spreadsheets/d/([^/]+)", parsed.path)
    if not sheet_id_match:
        return sheet_url

    query = parse_qs(parsed.query)
    fragment = parse_qs(parsed.fragment)
    gid = (query.get("gid") or fragment.get("gid") or ["0"])[0]
    sheet_id = sheet_id_match.group(1)

    return f"https://docs.google.com/spreadsheets/d/{sheet_id}/export?format=csv&gid={gid}"


def _pick_field(fieldnames: list[str], aliases: list[str]) -> str | None:
    alias_set = {_norm_key(value) for value in aliases}

    for field in fieldnames:
        if _norm_key(field) in alias_set:
            return field

    for field in fieldnames:
        normalized = _norm_key(field)
        if any(alias in normalized for alias in alias_set):
            return field

    return None


def _parse_price(raw_price: str) -> float | None:
    cleaned = raw_price.strip().replace(" ", "").replace(",", ".")
    if not cleaned:
        return None
    try:
        return float(cleaned)
    except ValueError:
        return None


def _canonical_row(row_no: int, row: dict[str, str], fieldnames: list[str]) -> dict[str, Any]:
    model_field = _pick_field(fieldnames, ["model", "модел", "код", "артикул", "sku"])
    name_field = _pick_field(
        fieldnames,
        ["product", "махсулот", "товар", "название", "наименование", "model_name"],
    )
    category_field = _pick_field(fieldnames, ["category", "категория"])
    size_field = _pick_field(fieldnames, ["size", "размер"])
    section_field = _pick_field(
        fieldnames,
        ["modelbulim", "моделбулим", "булим", "season", "сезон", "отдел"],
    )
    price_field = _pick_field(
        fieldnames,
        ["price", "сотишнарх", "нарх", "цена", "sellingprice", "saleprice"],
    )

    sku = (row.get(model_field) or "").strip() if model_field else ""
    product_name = (row.get(name_field) or "").strip() if name_field else ""
    category = (row.get(category_field) or "").strip() if category_field else ""
    size = (row.get(size_field) or "").strip() if size_field else ""
    section = (row.get(section_field) or "").strip() if section_field else ""
    price_text = (row.get(price_field) or "").strip() if price_field else ""
    price_value = _parse_price(price_text)

    return {
        "row_no": row_no,
        "sku": sku,
        "product_name": product_name,
        "category": category,
        "size": size,
        "section": section,
        "price": price_text,
        "price_value": price_value,
        "raw": {key: (value or "").strip() for key, value in row.items()},
    }


def _has_any_data(row: dict[str, Any]) -> bool:
    fields = ["sku", "product_name", "category", "size", "section", "price"]
    return any((row.get(field) or "").strip() for field in fields)


async def _fetch_rows_from_sheet() -> tuple[list[dict[str, Any]], list[str], str]:
    export_url = _build_export_url(PRODUCT_SHEET_URL)

    async with httpx.AsyncClient(timeout=PRODUCT_SHEET_TIMEOUT_SECONDS, follow_redirects=True) as client:
        response = await client.get(export_url)

    if response.status_code != 200:
        raise RuntimeError(
            f"Could not load Google Sheet (HTTP {response.status_code}) from {export_url}."
        )

    body = response.text
    if "<html" in body[:2000].lower():
        raise RuntimeError(
            "Google Sheet returned HTML instead of CSV. "
            "Set sheet access to 'Anyone with the link can view'."
        )

    reader = csv.DictReader(io.StringIO(body))
    fieldnames = [field or "" for field in (reader.fieldnames or [])]
    if not fieldnames:
        raise RuntimeError("Google Sheet CSV has no header row.")

    rows: list[dict[str, Any]] = []
    for index, raw_row in enumerate(reader, start=2):
        row = _canonical_row(index, raw_row, fieldnames)
        if _has_any_data(row):
            rows.append(row)

    return rows, fieldnames, export_url


async def _get_rows(force_refresh: bool = False) -> tuple[list[dict[str, Any]], list[str], str]:
    global _CACHE_ROWS, _CACHE_HEADERS, _CACHE_SOURCE_URL, _CACHE_LOADED_AT_TS

    now = time.time()
    cache_is_fresh = (
        not force_refresh
        and _CACHE_ROWS is not None
        and (now - _CACHE_LOADED_AT_TS) < PRODUCT_SHEET_CACHE_TTL_SECONDS
    )
    if cache_is_fresh:
        return _CACHE_ROWS, _CACHE_HEADERS, _CACHE_SOURCE_URL

    rows, headers, source_url = await _fetch_rows_from_sheet()
    _CACHE_ROWS = rows
    _CACHE_HEADERS = headers
    _CACHE_SOURCE_URL = source_url
    _CACHE_LOADED_AT_TS = now
    return rows, headers, source_url


async def list_product_prices(limit: int = 50, force_refresh: bool = False) -> str:
    rows, headers, source_url = await _get_rows(force_refresh=force_refresh)
    bounded_limit = max(1, min(int(limit), 500))
    payload = {
        "source_url": source_url,
        "headers": headers,
        "count": len(rows),
        "items": rows[:bounded_limit],
    }
    return json.dumps(payload, ensure_ascii=False, indent=2)


async def search_product_prices(query: str, limit: int = 25, force_refresh: bool = False) -> str:
    term = query.strip().lower()
    if not term:
        return "Search query is empty."

    rows, headers, source_url = await _get_rows(force_refresh=force_refresh)
    matches: list[dict[str, Any]] = []

    for row in rows:
        haystack_parts = [
            row.get("sku") or "",
            row.get("product_name") or "",
            row.get("category") or "",
            row.get("size") or "",
            row.get("section") or "",
            row.get("price") or "",
            json.dumps(row.get("raw", {}), ensure_ascii=False),
        ]
        haystack = " ".join(haystack_parts).lower()
        if term in haystack:
            matches.append(row)

    bounded_limit = max(1, min(int(limit), 500))
    payload = {
        "source_url": source_url,
        "headers": headers,
        "query": query,
        "count": len(matches),
        "items": matches[:bounded_limit],
    }
    return json.dumps(payload, ensure_ascii=False, indent=2)


async def get_product_sheet_status(force_refresh: bool = False) -> str:
    rows, headers, source_url = await _get_rows(force_refresh=force_refresh)
    payload = {
        "configured_sheet_url": PRODUCT_SHEET_URL,
        "resolved_csv_url": source_url,
        "cache_ttl_seconds": PRODUCT_SHEET_CACHE_TTL_SECONDS,
        "loaded_rows": len(rows),
        "headers": headers,
    }
    return json.dumps(payload, ensure_ascii=False, indent=2)
