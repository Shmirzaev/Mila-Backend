import asyncio
import os
import sys

import uvicorn

from env_config import env_bool, env_int, load_project_env


load_project_env()


def run_web() -> None:
    uvicorn.run(
        "token_server:app",
        host=os.getenv("HOST", "0.0.0.0"),
        port=env_int("PORT", 8000),
        reload=env_bool("UVICORN_RELOAD", default=False),
    )


def run_worker() -> None:
    from agent import server
    from livekit.agents import cli

    command = os.getenv("LIVEKIT_AGENT_COMMAND", "start").strip() or "start"
    sys.argv = [sys.argv[0], command]
    cli.run_app(server)


def run_import_employees() -> None:
    from import_employees import main

    asyncio.run(main())


def run_bootstrap_db() -> None:
    from bootstrap_database import main

    asyncio.run(main())


def main() -> None:
    mode = os.getenv("MILA_SERVICE_MODE", "web").strip().lower()

    if mode == "web":
        run_web()
        return

    if mode == "worker":
        run_worker()
        return

    if mode == "import-employees":
        run_import_employees()
        return

    if mode == "bootstrap-db":
        run_bootstrap_db()
        return

    raise RuntimeError(
        "Unsupported MILA_SERVICE_MODE. Use one of: "
        "web, worker, import-employees, bootstrap-db."
    )


if __name__ == "__main__":
    main()
