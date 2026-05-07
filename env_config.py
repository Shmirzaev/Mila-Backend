import os
from pathlib import Path

from dotenv import load_dotenv


PROJECT_ROOT = Path(__file__).resolve().parent


def load_project_env() -> tuple[Path, ...]:
    loaded_files: list[Path] = []

    configured_env_file = os.getenv("MILA_ENV_FILE", "").strip()
    if configured_env_file:
        env_path = Path(configured_env_file).expanduser()
        if env_path.exists():
            load_dotenv(env_path, override=False)
            loaded_files.append(env_path.resolve())
        return tuple(loaded_files)

    for filename in (".env", ".env.local"):
        env_path = PROJECT_ROOT / filename
        if env_path.exists():
            load_dotenv(env_path, override=False)
            loaded_files.append(env_path.resolve())

    return tuple(loaded_files)


LOADED_ENV_FILES = load_project_env()


def env_bool(name: str, default: bool = False) -> bool:
    raw_value = os.getenv(name)
    if raw_value is None:
        return default
    return raw_value.strip().lower() in {"1", "true", "yes", "on"}


def env_int(name: str, default: int) -> int:
    raw_value = os.getenv(name)
    if raw_value is None or not raw_value.strip():
        return default
    return int(raw_value)
