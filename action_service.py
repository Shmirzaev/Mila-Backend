import os
import json
from typing import Any

import asyncpg

from telegram_service import send_staff_announcement, send_private_telegram_message
from env_config import load_project_env


load_project_env()

DATABASE_URL = os.getenv("DATABASE_URL")
ACTION_USER_ID = os.getenv("MEMORY_USER_ID", "ceo_vechi_nazar")
ACTION_COMPANY_ID = os.getenv("MEMORY_COMPANY_ID", "milana_premium")


def _require_database_url() -> str:
    if not DATABASE_URL:
        raise RuntimeError("DATABASE_URL is missing from the environment.")
    return DATABASE_URL


async def _connect() -> asyncpg.Connection:
    return await asyncpg.connect(_require_database_url())


def _payload_to_json(payload: dict[str, Any]) -> str:
    return json.dumps(payload, ensure_ascii=False)


def _json_to_dict(value: Any) -> dict[str, Any]:
    if value is None:
        return {}

    if isinstance(value, dict):
        return value

    if isinstance(value, str):
        return json.loads(value)

    return dict(value)


async def init_action_pool() -> None:
    """
    Compatibility function.
    We do not keep a global asyncpg pool because LiveKit tools may run in different event loops.
    """
    conn = await _connect()
    try:
        await conn.execute("SELECT 1")
    finally:
        await conn.close()


async def create_pending_action(
    action_type: str,
    target: str,
    payload: dict[str, Any],
    user_id: str = ACTION_USER_ID,
    company_id: str = ACTION_COMPANY_ID,
) -> str:
    conn = await _connect()

    try:
        async with conn.transaction():
            action_id = await conn.fetchval(
                """
                INSERT INTO pending_actions (
                    user_id,
                    company_id,
                    action_type,
                    target,
                    payload,
                    status
                )
                VALUES ($1, $2, $3, $4, $5::jsonb, 'pending')
                RETURNING id
                """,
                user_id,
                company_id,
                action_type,
                target,
                _payload_to_json(payload),
            )

            await conn.execute(
                """
                INSERT INTO action_logs (
                    action_id,
                    user_id,
                    company_id,
                    action_type,
                    target,
                    payload,
                    status,
                    result
                )
                VALUES (
                    $1,
                    $2,
                    $3,
                    $4,
                    $5,
                    $6::jsonb,
                    'pending',
                    'Action prepared and waiting for CEO confirmation'
                )
                """,
                action_id,
                user_id,
                company_id,
                action_type,
                target,
                _payload_to_json(payload),
            )

        return str(action_id)

    finally:
        await conn.close()


async def list_pending_actions(
    user_id: str = ACTION_USER_ID,
    limit: int = 5,
) -> str:
    conn = await _connect()

    try:
        rows = await conn.fetch(
            """
            SELECT
                id,
                action_type,
                target,
                payload,
                status,
                created_at
            FROM pending_actions
            WHERE user_id = $1
              AND status = 'pending'
            ORDER BY created_at DESC
            LIMIT $2
            """,
            user_id,
            int(limit),
        )

        if not rows:
            return "No pending actions."

        result = []

        for row in rows:
            result.append(
                {
                    "id": str(row["id"]),
                    "action_type": row["action_type"],
                    "target": row["target"],
                    "payload": _json_to_dict(row["payload"]),
                    "status": row["status"],
                    "created_at": str(row["created_at"]),
                }
            )

        return json.dumps(result, ensure_ascii=False, indent=2)

    finally:
        await conn.close()


async def get_latest_pending_action(
    user_id: str = ACTION_USER_ID,
) -> dict[str, Any] | None:
    conn = await _connect()

    try:
        row = await conn.fetchrow(
            """
            SELECT
                id,
                action_type,
                target,
                payload,
                status
            FROM pending_actions
            WHERE user_id = $1
              AND status = 'pending'
            ORDER BY created_at DESC
            LIMIT 1
            """,
            user_id,
        )

        if not row:
            return None

        return {
            "id": str(row["id"]),
            "action_type": row["action_type"],
            "target": row["target"],
            "payload": _json_to_dict(row["payload"]),
            "status": row["status"],
        }

    finally:
        await conn.close()


async def cancel_latest_pending_action(
    user_id: str = ACTION_USER_ID,
) -> str:
    action = await get_latest_pending_action(user_id=user_id)

    if not action:
        return "No pending action to cancel."

    action_id = action["id"]

    conn = await _connect()

    try:
        async with conn.transaction():
            await conn.execute(
                """
                UPDATE pending_actions
                SET status = 'cancelled',
                    cancelled_at = NOW()
                WHERE id = $1::uuid
                """,
                action_id,
            )

            await conn.execute(
                """
                INSERT INTO action_logs (
                    action_id,
                    user_id,
                    company_id,
                    action_type,
                    target,
                    payload,
                    status,
                    result
                )
                VALUES (
                    $1::uuid,
                    $2,
                    $3,
                    $4,
                    $5,
                    $6::jsonb,
                    'cancelled',
                    'Action cancelled by CEO'
                )
                """,
                action_id,
                user_id,
                ACTION_COMPANY_ID,
                action["action_type"],
                action["target"],
                _payload_to_json(action["payload"]),
            )

        return f"Pending action cancelled. ID: {action_id}"

    finally:
        await conn.close()


async def execute_latest_pending_action(
    confirmation_text: str,
    user_id: str = ACTION_USER_ID,
) -> str:
    if not confirmation_text or len(confirmation_text.strip()) < 2:
        return "Execution blocked: explicit CEO confirmation text is required."

    action = await get_latest_pending_action(user_id=user_id)

    if not action:
        return "No pending action to execute."

    action_id = action["id"]
    action_type = action["action_type"]
    target = action["target"]
    payload = action["payload"]

    try:
        if action_type == "telegram_staff_announcement":
            title = payload.get("title", "Объявление")
            message = payload.get("message", "")
            urgent = bool(payload.get("urgent", False))

            if not message.strip():
                raise RuntimeError("Telegram message is empty.")

            result = await send_staff_announcement(
                title=title,
                message=message,
                urgent=urgent,
            )

        elif action_type == "telegram_employee_private_message":
            chat_id = payload.get("chat_id", "")
            title = payload.get("title", "Личное сообщение")
            message = payload.get("message", "")
            urgent = bool(payload.get("urgent", False))

            if not chat_id:
                raise RuntimeError("Employee telegram_chat_id is empty.")

            if not message.strip():
                raise RuntimeError("Telegram private message is empty.")

            result = await send_private_telegram_message(
                chat_id=chat_id,
                title=title,
                message=message,
                urgent=urgent,
            )

        else:
            raise RuntimeError(f"Unsupported action_type: {action_type}")

        conn = await _connect()

        try:
            async with conn.transaction():
                await conn.execute(
                    """
                    UPDATE pending_actions
                    SET status = 'executed',
                        confirmed_at = NOW(),
                        executed_at = NOW(),
                        error_message = NULL
                    WHERE id = $1::uuid
                    """,
                    action_id,
                )

                await conn.execute(
                    """
                    INSERT INTO action_logs (
                        action_id,
                        user_id,
                        company_id,
                        action_type,
                        target,
                        payload,
                        status,
                        result
                    )
                    VALUES (
                        $1::uuid,
                        $2,
                        $3,
                        $4,
                        $5,
                        $6::jsonb,
                        'executed',
                        $7
                    )
                    """,
                    action_id,
                    user_id,
                    ACTION_COMPANY_ID,
                    action_type,
                    target,
                    _payload_to_json(payload),
                    result,
                )

        finally:
            await conn.close()

        return f"Action executed successfully. ID: {action_id}. Result: {result}"

    except Exception as e:
        error_message = str(e)

        conn = await _connect()

        try:
            async with conn.transaction():
                await conn.execute(
                    """
                    UPDATE pending_actions
                    SET status = 'failed',
                        error_message = $2
                    WHERE id = $1::uuid
                    """,
                    action_id,
                    error_message,
                )

                await conn.execute(
                    """
                    INSERT INTO action_logs (
                        action_id,
                        user_id,
                        company_id,
                        action_type,
                        target,
                        payload,
                        status,
                        result
                    )
                    VALUES (
                        $1::uuid,
                        $2,
                        $3,
                        $4,
                        $5,
                        $6::jsonb,
                        'failed',
                        $7
                    )
                    """,
                    action_id,
                    user_id,
                    ACTION_COMPANY_ID,
                    action_type,
                    target,
                    _payload_to_json(payload),
                    error_message,
                )

        finally:
            await conn.close()

        return f"Action failed. ID: {action_id}. Error: {error_message}"
