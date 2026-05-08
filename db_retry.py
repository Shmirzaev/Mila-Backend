import asyncio
import os
from collections.abc import Awaitable, Callable
from typing import Any, TypeVar

import asyncpg

from env_config import env_int, load_project_env


load_project_env()

DB_CONNECT_MAX_ATTEMPTS = env_int("MILA_DB_CONNECT_MAX_ATTEMPTS", 20)


def _env_float(name: str, default: float) -> float:
    raw_value = os.getenv(name)
    if raw_value is None or not raw_value.strip():
        return default
    return float(raw_value)


DB_CONNECT_RETRY_DELAY_SECONDS = _env_float(
    "MILA_DB_CONNECT_RETRY_DELAY_SECONDS",
    1.0,
)
T = TypeVar("T")


def _is_retryable_db_error(error: Exception) -> bool:
    if isinstance(
        error,
        (
            ConnectionRefusedError,
            TimeoutError,
            OSError,
            asyncpg.exceptions.CannotConnectNowError,
            asyncpg.exceptions.PostgresConnectionError,
        ),
    ):
        return True

    message = str(error).lower()
    return (
        "starting up" in message
        or "refused" in message
        or "could not connect" in message
        or "cannot connect now" in message
    )


async def _retry_db_operation(
    label: str,
    operation: Callable[[], Awaitable[T]],
) -> T:
    last_error: Exception | None = None

    for attempt in range(1, DB_CONNECT_MAX_ATTEMPTS + 1):
        try:
            return await operation()
        except Exception as error:
            if not _is_retryable_db_error(error) or attempt == DB_CONNECT_MAX_ATTEMPTS:
                raise

            last_error = error
            print(
                f"WARNING: {label} failed "
                f"(attempt {attempt}/{DB_CONNECT_MAX_ATTEMPTS}): {error}. "
                f"Retrying in {DB_CONNECT_RETRY_DELAY_SECONDS:.1f}s..."
            )
            await asyncio.sleep(DB_CONNECT_RETRY_DELAY_SECONDS)

    if last_error is not None:
        raise last_error

    raise RuntimeError(f"{label} failed without returning a result.")


async def connect_with_retry(database_url: str) -> asyncpg.Connection:
    return await _retry_db_operation(
        "database connect",
        lambda: asyncpg.connect(database_url),
    )


async def create_pool_with_retry(database_url: str, **kwargs: Any) -> asyncpg.Pool:
    return await _retry_db_operation(
        "database pool init",
        lambda: asyncpg.create_pool(database_url, **kwargs),
    )
