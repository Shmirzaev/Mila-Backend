import csv
import asyncio
import os
from pathlib import Path

import asyncpg
from env_config import load_project_env


load_project_env()

DATABASE_URL = os.getenv("DATABASE_URL")
PROJECT_ROOT = Path(__file__).resolve().parent
DEFAULT_CSV_PATH = PROJECT_ROOT / "imports" / "employees.csv"
CSV_PATH = Path(os.getenv("EMPLOYEES_CSV_PATH", str(DEFAULT_CSV_PATH)))


def clean(value: str | None) -> str:
    return (value or "").strip()


async def main():
    if not DATABASE_URL:
        raise RuntimeError("DATABASE_URL is missing from the environment.")

    if not CSV_PATH.exists():
        raise RuntimeError(f"CSV file not found: {CSV_PATH}")

    conn = await asyncpg.connect(DATABASE_URL)

    imported = 0
    skipped = 0

    try:
        with CSV_PATH.open("r", encoding="utf-8-sig", newline="") as file:
            reader = csv.DictReader(file)

            required_columns = {
                "employee_no",
                "full_name",
                "short_name",
                "department_key",
                "position",
                "phone",
                "telegram_username",
                "telegram_chat_id",
                "access_level",
                "status",
                "notes",
            }

            missing_columns = required_columns - set(reader.fieldnames or [])

            if missing_columns:
                raise RuntimeError(f"Missing columns in employees.csv: {missing_columns}")

            for row_number, row in enumerate(reader, start=2):
                employee_no_raw = clean(row.get("employee_no"))
                full_name = clean(row.get("full_name"))
                short_name = clean(row.get("short_name"))
                department_key = clean(row.get("department_key"))
                position = clean(row.get("position"))
                phone = clean(row.get("phone"))
                telegram_username = clean(row.get("telegram_username"))
                telegram_chat_id = clean(row.get("telegram_chat_id"))
                access_level = clean(row.get("access_level")) or "employee"
                status = clean(row.get("status")) or "active"
                notes = clean(row.get("notes"))

                if not employee_no_raw:
                    print(f"SKIPPED row {row_number}: employee_no is empty")
                    skipped += 1
                    continue

                try:
                    employee_no = int(employee_no_raw)
                except ValueError:
                    print(f"SKIPPED row {row_number}: employee_no must be a number: {employee_no_raw}")
                    skipped += 1
                    continue

                if employee_no <= 0:
                    print(f"SKIPPED row {row_number}: employee_no must be positive: {employee_no}")
                    skipped += 1
                    continue

                if not full_name:
                    print(f"SKIPPED row {row_number}: full_name is empty")
                    skipped += 1
                    continue

                if not department_key:
                    print(f"SKIPPED row {row_number}: department_key is empty for {full_name}")
                    skipped += 1
                    continue

                if access_level not in {"ceo", "admin", "manager", "employee"}:
                    print(f"SKIPPED row {row_number}: wrong access_level '{access_level}' for {full_name}")
                    skipped += 1
                    continue

                if status not in {"active", "inactive", "fired", "vacation"}:
                    print(f"SKIPPED row {row_number}: wrong status '{status}' for {full_name}")
                    skipped += 1
                    continue

                department_id = await conn.fetchval(
                    """
                    SELECT id
                    FROM departments
                    WHERE department_key = $1
                      AND is_active = TRUE
                    """,
                    department_key,
                )

                if not department_id:
                    print(f"SKIPPED row {row_number}: department not found '{department_key}' for {full_name}")
                    skipped += 1
                    continue

                await conn.execute(
                    """
                    INSERT INTO employees (
                        employee_no,
                        full_name,
                        short_name,
                        department_id,
                        position,
                        phone,
                        telegram_username,
                        telegram_chat_id,
                        access_level,
                        status,
                        notes
                    )
                    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
                    ON CONFLICT (employee_no)
                    DO UPDATE SET
                        full_name = EXCLUDED.full_name,
                        short_name = EXCLUDED.short_name,
                        department_id = EXCLUDED.department_id,
                        position = EXCLUDED.position,
                        phone = EXCLUDED.phone,
                        telegram_username = EXCLUDED.telegram_username,
                        telegram_chat_id = EXCLUDED.telegram_chat_id,
                        access_level = EXCLUDED.access_level,
                        status = EXCLUDED.status,
                        notes = EXCLUDED.notes,
                        updated_at = NOW()
                    """,
                    employee_no,
                    full_name,
                    short_name,
                    department_id,
                    position,
                    phone,
                    telegram_username,
                    telegram_chat_id,
                    access_level,
                    status,
                    notes,
                )

                print(f"IMPORTED/UPDATED: #{employee_no} {full_name}")
                imported += 1

        print("")
        print("EMPLOYEE IMPORT COMPLETED")
        print(f"Imported/updated: {imported}")
        print(f"Skipped: {skipped}")

    finally:
        await conn.close()


if __name__ == "__main__":
    asyncio.run(main())
