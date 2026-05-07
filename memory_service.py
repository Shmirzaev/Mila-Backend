import os
import json
import asyncio
from typing import Any

import asyncpg
from google import genai
from google.genai import types
from env_config import load_project_env


load_project_env()

DATABASE_URL = os.getenv("DATABASE_URL")
GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY")

MEMORY_USER_ID = os.getenv("MEMORY_USER_ID", "ceo_vechi_nazar")
MEMORY_COMPANY_ID = os.getenv("MEMORY_COMPANY_ID", "milana_premium")
EMBEDDING_MODEL = os.getenv("MEMORY_EMBEDDING_MODEL", "gemini-embedding-2")
EMBEDDING_DIM = int(os.getenv("MEMORY_EMBEDDING_DIM", "768"))

_pool: asyncpg.Pool | None = None
_genai_client = genai.Client(api_key=GOOGLE_API_KEY)


async def init_memory_pool() -> None:
    global _pool

    if not DATABASE_URL:
        raise RuntimeError("DATABASE_URL is missing from the environment.")

    if _pool is None:
        _pool = await asyncpg.create_pool(
            DATABASE_URL,
            min_size=1,
            max_size=10,
            command_timeout=30,
        )


async def close_memory_pool() -> None:
    global _pool

    if _pool is not None:
        await _pool.close()
        _pool = None


def _vector_to_pg(values: list[float]) -> str:
    return "[" + ",".join(str(float(v)) for v in values) + "]"


def _prepare_document(title: str, content: str) -> str:
    return f"title: {title} | text: {content}"


def _prepare_query(query: str) -> str:
    return f"task: search result | query: {query}"


def _embed_sync(text: str) -> list[float]:
    result = _genai_client.models.embed_content(
        model=EMBEDDING_MODEL,
        contents=text,
        config=types.EmbedContentConfig(
            output_dimensionality=EMBEDDING_DIM,
        ),
    )

    values = result.embeddings[0].values

    if len(values) != EMBEDDING_DIM:
        raise RuntimeError(
            f"Embedding dimension mismatch. Expected {EMBEDDING_DIM}, got {len(values)}"
        )

    return [float(v) for v in values]


async def embed_text(text: str) -> list[float]:
    return await asyncio.to_thread(_embed_sync, text)


async def save_memory(
    title: str,
    content: str,
    category: str = "general",
    memory_type: str = "fact",
    importance: int = 3,
    tags: list[str] | None = None,
    source: str = "voice_assistant",
    user_id: str = MEMORY_USER_ID,
    company_id: str = MEMORY_COMPANY_ID,
) -> str:
    if _pool is None:
        await init_memory_pool()

    tags = tags or []

    clean_title = title.strip()
    clean_content = content.strip()

    if not clean_title or not clean_content:
        return "Memory was not saved: title or content is empty."

    importance = max(1, min(int(importance), 5))

    document_text = _prepare_document(clean_title, clean_content)
    embedding = await embed_text(document_text)
    embedding_pg = _vector_to_pg(embedding)

    async with _pool.acquire() as conn:
        async with conn.transaction():
            memory_id = await conn.fetchval(
                """
                INSERT INTO ai_memory (
                    user_id,
                    company_id,
                    category,
                    memory_type,
                    title,
                    content,
                    source,
                    importance,
                    tags
                )
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
                RETURNING id
                """,
                user_id,
                company_id,
                category,
                memory_type,
                clean_title,
                clean_content,
                source,
                importance,
                tags,
            )

            await conn.execute(
                """
                INSERT INTO ai_memory_embeddings (
                    memory_id,
                    embedding,
                    embedding_model
                )
                VALUES ($1, $2::vector, $3)
                """,
                memory_id,
                embedding_pg,
                EMBEDDING_MODEL,
            )

            await conn.execute(
                """
                INSERT INTO ai_memory_audit (
                    memory_id,
                    action,
                    user_id,
                    new_content
                )
                VALUES ($1, 'create', $2, $3)
                """,
                memory_id,
                user_id,
                clean_content,
            )

    return f"Memory saved successfully. ID: {memory_id}"


async def search_memory(
    query: str,
    limit: int = 5,
    user_id: str = MEMORY_USER_ID,
) -> str:
    if _pool is None:
        await init_memory_pool()

    clean_query = query.strip()

    if not clean_query:
        return "Search query is empty."

    query_embedding = await embed_text(_prepare_query(clean_query))
    query_embedding_pg = _vector_to_pg(query_embedding)

    async with _pool.acquire() as conn:
        rows = await conn.fetch(
            """
            SELECT
                m.id,
                m.category,
                m.memory_type,
                m.title,
                m.content,
                m.importance,
                m.tags,
                1 - (e.embedding <=> $1::vector) AS similarity
            FROM ai_memory m
            JOIN ai_memory_embeddings e ON e.memory_id = m.id
            WHERE m.user_id = $2
              AND m.status = 'active'
            ORDER BY e.embedding <=> $1::vector
            LIMIT $3
            """,
            query_embedding_pg,
            user_id,
            int(limit),
        )

    if not rows:
        return "No relevant long-term memory found."

    results = []

    for row in rows:
        results.append(
            {
                "id": str(row["id"]),
                "category": row["category"],
                "type": row["memory_type"],
                "title": row["title"],
                "content": row["content"],
                "importance": row["importance"],
                "tags": row["tags"],
                "similarity": round(float(row["similarity"]), 4),
            }
        )

    return json.dumps(results, ensure_ascii=False, indent=2)


async def get_startup_memory(
    user_id: str = MEMORY_USER_ID,
    limit: int = 20,
) -> str:
    if _pool is None:
        await init_memory_pool()

    async with _pool.acquire() as conn:
        rows = await conn.fetch(
            """
            SELECT
                category,
                memory_type,
                title,
                content,
                importance
            FROM ai_memory
            WHERE user_id = $1
              AND status = 'active'
              AND importance >= 3
            ORDER BY importance DESC, updated_at DESC
            LIMIT $2
            """,
            user_id,
            int(limit),
        )

    if not rows:
        return "No saved long-term memory yet."

    lines = []

    for row in rows:
        lines.append(
            f"- [{row['category']} / {row['memory_type']} / importance {row['importance']}] "
            f"{row['title']}: {row['content']}"
        )

    return "\n".join(lines)


async def forget_memory(
    keyword: str,
    user_id: str = MEMORY_USER_ID,
) -> str:
    if _pool is None:
        await init_memory_pool()

    clean_keyword = keyword.strip()

    if not clean_keyword:
        return "Nothing was deleted: keyword is empty."

    async with _pool.acquire() as conn:
        rows = await conn.fetch(
            """
            UPDATE ai_memory
            SET status = 'deleted',
                updated_at = NOW()
            WHERE user_id = $1
              AND status = 'active'
              AND (
                    title ILIKE '%' || $2 || '%'
                    OR content ILIKE '%' || $2 || '%'
                  )
            RETURNING id, title, content
            """,
            user_id,
            clean_keyword,
        )

        for row in rows:
            await conn.execute(
                """
                INSERT INTO ai_memory_audit (
                    memory_id,
                    action,
                    user_id,
                    old_content
                )
                VALUES ($1, 'delete', $2, $3)
                """,
                row["id"],
                user_id,
                row["content"],
            )

    if not rows:
        return "No matching memory found to delete."

    return f"Deleted {len(rows)} memory item(s)."


async def list_recent_memory(
    user_id: str = MEMORY_USER_ID,
    limit: int = 10,
) -> str:
    if _pool is None:
        await init_memory_pool()

    async with _pool.acquire() as conn:
        rows = await conn.fetch(
            """
            SELECT
                id,
                category,
                memory_type,
                title,
                content,
                importance,
                created_at
            FROM ai_memory
            WHERE user_id = $1
              AND status = 'active'
            ORDER BY created_at DESC
            LIMIT $2
            """,
            user_id,
            int(limit),
        )

    if not rows:
        return "No saved memory yet."

    result = []

    for row in rows:
        result.append(
            {
                "id": str(row["id"]),
                "category": row["category"],
                "type": row["memory_type"],
                "title": row["title"],
                "content": row["content"],
                "importance": row["importance"],
                "created_at": str(row["created_at"]),
            }
        )

    return json.dumps(result, ensure_ascii=False, indent=2)
