from pathlib import Path

import asyncpg

from env_config import load_project_env


load_project_env()

PROJECT_ROOT = Path(__file__).resolve().parent
SQL_DIR = PROJECT_ROOT / "db"
SQL_FILES = ("init.sql", "employees.sql", "action_layer.sql")


async def main() -> None:
    import os

    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        raise RuntimeError("DATABASE_URL is missing from the environment.")

    conn = await asyncpg.connect(database_url)
    try:
        for filename in SQL_FILES:
            sql_path = SQL_DIR / filename
            sql = sql_path.read_text(encoding="utf-8")
            await conn.execute(sql)
            print(f"Applied {sql_path.name}")
    finally:
        await conn.close()


if __name__ == "__main__":
    import asyncio

    asyncio.run(main())
