import io
import json
import os
import re
import time
from html import unescape
from urllib.parse import parse_qs, urlparse

import httpx
from pypdf import PdfReader

from env_config import load_project_env


load_project_env()

DEFAULT_PRODUCT_PDF_URLS = [
    "https://drive.google.com/file/d/1Lg1RgO1uc3G3PkhENrwO6sP-i2X8h6Vz/preview",
    "https://drive.google.com/file/d/1tAKAPe2o3nusdtc0QQ_WotdYJDtGPYi5/preview",
    "https://drive.google.com/file/d/1iNQn7Lr2Tz0cijjyecHtbMC-VH8drhuf/preview",
    "https://drive.google.com/file/d/1m22AYrRWdailkYRV_ZC_tfQlJacIGdLU/preview",
]

PRODUCT_PDF_URLS_RAW = os.getenv("MILA_PRODUCT_CATALOG_PDF_URLS", "").strip()
if PRODUCT_PDF_URLS_RAW:
    PRODUCT_PDF_URLS = [
        item.strip()
        for item in re.split(r"[\n,;]+", PRODUCT_PDF_URLS_RAW)
        if item.strip()
    ]
else:
    PRODUCT_PDF_URLS = DEFAULT_PRODUCT_PDF_URLS

PRODUCT_PDF_TIMEOUT_SECONDS = float(
    os.getenv("MILA_PRODUCT_PDF_TIMEOUT_SECONDS", "30").strip() or "30"
)
PRODUCT_PDF_CACHE_TTL_SECONDS = max(
    30,
    int(os.getenv("MILA_PRODUCT_PDF_CACHE_TTL_SECONDS", "300").strip() or "300"),
)
MAX_LINES_PER_PDF = max(
    300,
    int(os.getenv("MILA_PRODUCT_PDF_MAX_LINES_PER_PDF", "8000").strip() or "8000"),
)

_CACHE_ITEMS: list[dict] | None = None
_CACHE_METADATA: list[dict] = []
_CACHE_LOADED_AT_TS: float = 0.0


def _extract_drive_file_id(url: str) -> str | None:
    match = re.search(r"/file/d/([A-Za-z0-9_-]+)", url)
    if match:
        return match.group(1)

    parsed = urlparse(url)
    query = parse_qs(parsed.query)
    ids = query.get("id", [])
    if ids:
        return ids[0]

    return None


def _to_download_candidate_urls(source_url: str) -> list[str]:
    file_id = _extract_drive_file_id(source_url)
    if not file_id:
        return [source_url]

    return [
        f"https://drive.google.com/uc?export=download&id={file_id}",
        f"https://docs.google.com/uc?export=download&id={file_id}",
    ]


def _extract_confirmed_drive_url(html: str, file_id: str | None) -> str | None:
    if not file_id:
        return None

    href_match = re.search(
        r'id="uc-download-link"[^>]+href="([^"]+)"',
        html,
        flags=re.IGNORECASE,
    )
    if href_match:
        href = unescape(href_match.group(1)).replace("&amp;", "&")
        if href.startswith("/"):
            return f"https://drive.google.com{href}"
        return href

    token_match = re.search(r"confirm=([0-9A-Za-z_-]+)", html)
    if token_match:
        token = token_match.group(1)
        return (
            "https://drive.google.com/uc?export=download"
            f"&confirm={token}&id={file_id}"
        )

    return None


async def _download_pdf_bytes(source_url: str) -> tuple[bytes, str]:
    file_id = _extract_drive_file_id(source_url)
    candidate_urls = _to_download_candidate_urls(source_url)

    async with httpx.AsyncClient(
        timeout=PRODUCT_PDF_TIMEOUT_SECONDS,
        follow_redirects=True,
    ) as client:
        for candidate in candidate_urls:
            response = await client.get(candidate)
            content_type = (response.headers.get("content-type") or "").lower()
            body = response.content

            if body.startswith(b"%PDF") or "application/pdf" in content_type:
                return body, candidate

            if "text/html" in content_type:
                html = response.text
                confirmed_url = _extract_confirmed_drive_url(html, file_id=file_id)
                if confirmed_url:
                    confirmed = await client.get(confirmed_url)
                    confirmed_type = (confirmed.headers.get("content-type") or "").lower()
                    if confirmed.content.startswith(b"%PDF") or "application/pdf" in confirmed_type:
                        return confirmed.content, confirmed_url

    raise RuntimeError(
        "Could not download catalog PDF. Make sure each Drive file allows "
        "'Anyone with the link can view'."
    )


def _extract_pdf_lines(pdf_bytes: bytes, source_url: str, resolved_url: str) -> tuple[list[dict], dict]:
    reader = PdfReader(io.BytesIO(pdf_bytes))
    lines: list[dict] = []
    page_count = len(reader.pages)
    line_count = 0

    for page_index, page in enumerate(reader.pages, start=1):
        try:
            text = page.extract_text() or ""
        except Exception:
            text = ""

        for raw_line in text.splitlines():
            line = re.sub(r"\s+", " ", raw_line).strip()
            if len(line) < 3:
                continue

            line_count += 1
            lines.append(
                {
                    "source_url": source_url,
                    "resolved_url": resolved_url,
                    "page": page_index,
                    "line_no": line_count,
                    "text": line,
                }
            )
            if line_count >= MAX_LINES_PER_PDF:
                break

        if line_count >= MAX_LINES_PER_PDF:
            break

    metadata = {
        "source_url": source_url,
        "resolved_url": resolved_url,
        "page_count": page_count,
        "line_count": len(lines),
    }
    return lines, metadata


async def _load_catalog_items() -> tuple[list[dict], list[dict]]:
    all_items: list[dict] = []
    metadata_rows: list[dict] = []

    for source_url in PRODUCT_PDF_URLS:
        try:
            pdf_bytes, resolved_url = await _download_pdf_bytes(source_url)
            lines, metadata = _extract_pdf_lines(
                pdf_bytes=pdf_bytes,
                source_url=source_url,
                resolved_url=resolved_url,
            )
            all_items.extend(lines)
            metadata_rows.append(metadata)
        except Exception as error:
            metadata_rows.append(
                {
                    "source_url": source_url,
                    "resolved_url": "",
                    "error": str(error),
                    "page_count": 0,
                    "line_count": 0,
                }
            )

    return all_items, metadata_rows


async def _get_catalog_items(force_refresh: bool = False) -> tuple[list[dict], list[dict]]:
    global _CACHE_ITEMS, _CACHE_METADATA, _CACHE_LOADED_AT_TS

    now = time.time()
    is_fresh = (
        not force_refresh
        and _CACHE_ITEMS is not None
        and (now - _CACHE_LOADED_AT_TS) < PRODUCT_PDF_CACHE_TTL_SECONDS
    )
    if is_fresh:
        return _CACHE_ITEMS, _CACHE_METADATA

    items, metadata = await _load_catalog_items()
    _CACHE_ITEMS = items
    _CACHE_METADATA = metadata
    _CACHE_LOADED_AT_TS = now
    return items, metadata


async def get_product_pdf_catalog_status(force_refresh: bool = False) -> str:
    items, metadata = await _get_catalog_items(force_refresh=force_refresh)
    payload = {
        "configured_urls": PRODUCT_PDF_URLS,
        "cache_ttl_seconds": PRODUCT_PDF_CACHE_TTL_SECONDS,
        "total_indexed_lines": len(items),
        "sources": metadata,
    }
    return json.dumps(payload, ensure_ascii=False, indent=2)


async def search_product_pdf_catalog(
    query: str,
    limit: int = 30,
    force_refresh: bool = False,
) -> str:
    term = query.strip().lower()
    if not term:
        return "Search query is empty."

    items, metadata = await _get_catalog_items(force_refresh=force_refresh)
    matches: list[dict] = []
    for row in items:
        if term in row["text"].lower():
            matches.append(row)

    bounded_limit = max(1, min(int(limit), 200))
    payload = {
        "query": query,
        "count": len(matches),
        "items": matches[:bounded_limit],
        "sources": metadata,
    }
    return json.dumps(payload, ensure_ascii=False, indent=2)
