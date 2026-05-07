import os
import html
import json

import asyncpg
from env_config import load_project_env


load_project_env()

DATABASE_URL = os.getenv("DATABASE_URL")


def _require_database_url() -> str:
    if not DATABASE_URL:
        raise RuntimeError("DATABASE_URL is missing from the environment.")
    return DATABASE_URL


async def _connect() -> asyncpg.Connection:
    return await asyncpg.connect(_require_database_url())


async def init_employee_pool() -> None:
    """
    Compatibility function.
    We do not keep a global asyncpg pool because LiveKit tools may run in different event loops.
    """
    conn = await _connect()
    try:
        await conn.execute("SELECT 1")
    finally:
        await conn.close()


async def list_departments() -> str:
    conn = await _connect()

    try:
        rows = await conn.fetch(
            """
            SELECT
                department_key,
                title,
                description,
                is_active
            FROM departments
            WHERE is_active = TRUE
            ORDER BY title
            """
        )

        if not rows:
            return "No departments found."

        result = []

        for row in rows:
            result.append(
                {
                    "department_key": row["department_key"],
                    "title": row["title"],
                    "description": row["description"],
                    "is_active": row["is_active"],
                }
            )

        return json.dumps(result, ensure_ascii=False, indent=2)

    finally:
        await conn.close()


async def find_employee(query: str) -> str:
    conn = await _connect()

    try:
        clean_query = query.strip()

        if not clean_query:
            return "Search query is empty."

        rows = await conn.fetch(
            """
            SELECT
                e.id,
                e.employee_no,
                e.full_name,
                e.short_name,
                e.position,
                e.phone,
                e.telegram_username,
                e.telegram_chat_id,
                e.access_level,
                e.status,
                e.notes,
                d.department_key,
                d.title AS department_title
            FROM employees e
            LEFT JOIN departments d ON d.id = e.department_id
            WHERE e.status = 'active'
              AND (
                    e.employee_no::TEXT = $1
                    OR e.full_name ILIKE '%' || $1 || '%'
                    OR e.short_name ILIKE '%' || $1 || '%'
                    OR e.position ILIKE '%' || $1 || '%'
                    OR e.phone ILIKE '%' || $1 || '%'
                    OR e.telegram_username ILIKE '%' || $1 || '%'
                  )
            ORDER BY e.employee_no NULLS LAST, e.full_name
            LIMIT 20
            """,
            clean_query,
        )

        if not rows:
            return "No employees found."

        result = []

        for row in rows:
            result.append(
                {
                    "id": str(row["id"]),
                    "employee_no": row["employee_no"],
                    "full_name": row["full_name"],
                    "short_name": row["short_name"],
                    "position": row["position"],
                    "department_key": row["department_key"],
                    "department_title": row["department_title"],
                    "phone": row["phone"],
                    "telegram_username": row["telegram_username"],
                    "telegram_chat_id": row["telegram_chat_id"],
                    "access_level": row["access_level"],
                    "status": row["status"],
                    "notes": row["notes"],
                }
            )

        return json.dumps(result, ensure_ascii=False, indent=2)

    finally:
        await conn.close()


async def get_employee_by_number(employee_no: int) -> str:
    conn = await _connect()

    try:
        row = await conn.fetchrow(
            """
            SELECT
                e.id,
                e.employee_no,
                e.full_name,
                e.short_name,
                e.position,
                e.phone,
                e.telegram_username,
                e.telegram_chat_id,
                e.access_level,
                e.status,
                e.notes,
                d.department_key,
                d.title AS department_title
            FROM employees e
            LEFT JOIN departments d ON d.id = e.department_id
            WHERE e.employee_no = $1
            LIMIT 1
            """,
            int(employee_no),
        )

        if not row:
            return f"No employee found with employee_no={employee_no}."

        result = {
            "id": str(row["id"]),
            "employee_no": row["employee_no"],
            "full_name": row["full_name"],
            "short_name": row["short_name"],
            "position": row["position"],
            "department_key": row["department_key"],
            "department_title": row["department_title"],
            "phone": row["phone"],
            "telegram_username": row["telegram_username"],
            "telegram_chat_id": row["telegram_chat_id"],
            "access_level": row["access_level"],
            "status": row["status"],
            "notes": row["notes"],
        }

        return json.dumps(result, ensure_ascii=False, indent=2)

    finally:
        await conn.close()


async def get_employee_private_chat_data(employee_no: int) -> dict:
    conn = await _connect()

    try:
        row = await conn.fetchrow(
            """
            SELECT
                e.employee_no,
                e.full_name,
                e.position,
                e.telegram_username,
                e.telegram_chat_id,
                e.status,
                d.department_key,
                d.title AS department_title
            FROM employees e
            LEFT JOIN departments d ON d.id = e.department_id
            WHERE e.employee_no = $1
            LIMIT 1
            """,
            int(employee_no),
        )

        if not row:
            return {
                "ok": False,
                "error": f"No employee found with employee_no={employee_no}."
            }

        if row["status"] != "active":
            return {
                "ok": False,
                "error": f"Employee #{employee_no} is not active. Current status: {row['status']}."
            }

        if not row["telegram_chat_id"]:
            return {
                "ok": False,
                "error": f"Employee #{employee_no} has no telegram_chat_id."
            }

        return {
            "ok": True,
            "employee_no": row["employee_no"],
            "full_name": row["full_name"],
            "position": row["position"],
            "department_key": row["department_key"],
            "department_title": row["department_title"],
            "telegram_username": row["telegram_username"],
            "telegram_chat_id": row["telegram_chat_id"],
        }

    finally:
        await conn.close()


async def list_department_employees(department_key: str) -> str:
    conn = await _connect()

    try:
        clean_department_key = department_key.strip()

        if not clean_department_key:
            return "Department key is empty."

        rows = await conn.fetch(
            """
            SELECT
                e.employee_no,
                e.full_name,
                e.short_name,
                e.position,
                e.phone,
                e.telegram_username,
                e.telegram_chat_id,
                e.access_level,
                e.status,
                e.notes,
                d.department_key,
                d.title AS department_title
            FROM employees e
            JOIN departments d ON d.id = e.department_id
            WHERE d.department_key = $1
              AND e.status = 'active'
            ORDER BY e.employee_no NULLS LAST, e.full_name
            """,
            clean_department_key,
        )

        if not rows:
            return f"No active employees found in department: {clean_department_key}"

        result = []

        for row in rows:
            result.append(
                {
                    "employee_no": row["employee_no"],
                    "full_name": row["full_name"],
                    "short_name": row["short_name"],
                    "position": row["position"],
                    "department_key": row["department_key"],
                    "department_title": row["department_title"],
                    "phone": row["phone"],
                    "telegram_username": row["telegram_username"],
                    "telegram_chat_id": row["telegram_chat_id"],
                    "access_level": row["access_level"],
                    "status": row["status"],
                    "notes": row["notes"],
                }
            )

        return json.dumps(result, ensure_ascii=False, indent=2)

    finally:
        await conn.close()


async def list_all_active_employees(limit: int = 200) -> str:
    conn = await _connect()

    try:
        rows = await conn.fetch(
            """
            SELECT
                e.employee_no,
                e.full_name,
                e.short_name,
                e.position,
                e.phone,
                e.telegram_username,
                e.telegram_chat_id,
                e.access_level,
                e.status,
                d.department_key,
                d.title AS department_title
            FROM employees e
            LEFT JOIN departments d ON d.id = e.department_id
            WHERE e.status = 'active'
            ORDER BY e.employee_no NULLS LAST, e.full_name
            LIMIT $1
            """,
            int(limit),
        )

        if not rows:
            return "No active employees found."

        result = []

        for row in rows:
            result.append(
                {
                    "employee_no": row["employee_no"],
                    "full_name": row["full_name"],
                    "short_name": row["short_name"],
                    "position": row["position"],
                    "department_key": row["department_key"],
                    "department_title": row["department_title"],
                    "phone": row["phone"],
                    "telegram_username": row["telegram_username"],
                    "telegram_chat_id": row["telegram_chat_id"],
                    "access_level": row["access_level"],
                    "status": row["status"],
                }
            )

        return json.dumps(result, ensure_ascii=False, indent=2)

    finally:
        await conn.close()


async def list_telegram_targets() -> str:
    conn = await _connect()

    try:
        rows = await conn.fetch(
            """
            SELECT
                t.target_key,
                t.title,
                t.chat_id,
                t.target_type,
                t.is_active,
                d.department_key,
                d.title AS department_title
            FROM telegram_targets t
            LEFT JOIN departments d ON d.id = t.department_id
            WHERE t.is_active = TRUE
            ORDER BY t.title
            """
        )

        if not rows:
            return "No Telegram targets found."

        result = []

        for row in rows:
            result.append(
                {
                    "target_key": row["target_key"],
                    "title": row["title"],
                    "chat_id": row["chat_id"],
                    "target_type": row["target_type"],
                    "department_key": row["department_key"],
                    "department_title": row["department_title"],
                    "is_active": row["is_active"],
                }
            )

        return json.dumps(result, ensure_ascii=False, indent=2)

    finally:
        await conn.close()


async def get_telegram_target(target_key: str) -> str:
    conn = await _connect()

    try:
        clean_target_key = target_key.strip()

        if not clean_target_key:
            return "Target key is empty."

        row = await conn.fetchrow(
            """
            SELECT
                t.target_key,
                t.title,
                t.chat_id,
                t.target_type,
                t.is_active,
                d.department_key,
                d.title AS department_title
            FROM telegram_targets t
            LEFT JOIN departments d ON d.id = t.department_id
            WHERE t.target_key = $1
              AND t.is_active = TRUE
            LIMIT 1
            """,
            clean_target_key,
        )

        if not row:
            return f"No active Telegram target found: {clean_target_key}"

        result = {
            "target_key": row["target_key"],
            "title": row["title"],
            "chat_id": row["chat_id"],
            "target_type": row["target_type"],
            "department_key": row["department_key"],
            "department_title": row["department_title"],
            "is_active": row["is_active"],
        }

        return json.dumps(result, ensure_ascii=False, indent=2)

    finally:
        await conn.close()

