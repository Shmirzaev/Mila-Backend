import os
import uuid
import json
from fastapi import FastAPI, Request, HTTPException, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from livekit.api import (
    AccessToken,
    CreateAgentDispatchRequest,
    LiveKitAPI,
    VideoGrants,
    TwirpError,
)

from employee_service import get_all_active_employees_data
from env_config import LOADED_ENV_FILES, env_bool, env_int, load_project_env
from telegram_service import send_staff_attachment


load_project_env()

app = FastAPI()

LIVEKIT_URL = os.getenv("LIVEKIT_URL")
LIVEKIT_API_KEY = os.getenv("LIVEKIT_API_KEY")
LIVEKIT_API_SECRET = os.getenv("LIVEKIT_API_SECRET")
ENABLE_DEBUG_ENV = env_bool("ENABLE_DEBUG_ENV", default=False)
CORS_ALLOW_ORIGINS = [
    origin.strip()
    for origin in os.getenv("CORS_ALLOW_ORIGINS", "").split(",")
    if origin.strip()
]
CORS_ALLOW_ORIGIN_REGEX = os.getenv(
    "CORS_ALLOW_ORIGIN_REGEX",
    r"https?://(localhost|127\.0\.0\.1)(:\d+)?$",
)

AGENT_NAME = "mila-agent"

app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ALLOW_ORIGINS,
    allow_origin_regex=CORS_ALLOW_ORIGIN_REGEX,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def _missing_livekit_env_vars() -> list[str]:
    missing = []

    if not LIVEKIT_URL:
        missing.append("LIVEKIT_URL")
    if not LIVEKIT_API_KEY:
        missing.append("LIVEKIT_API_KEY")
    if not LIVEKIT_API_SECRET:
        missing.append("LIVEKIT_API_SECRET")

    return missing


async def _dispatch_agent_to_room(room_name: str, participant_source: str) -> None:
    metadata = json.dumps({"source": participant_source})

    async with LiveKitAPI(
        url=LIVEKIT_URL,
        api_key=LIVEKIT_API_KEY,
        api_secret=LIVEKIT_API_SECRET,
    ) as livekit_api:
        await livekit_api.agent_dispatch.create_dispatch(
            CreateAgentDispatchRequest(
                agent_name=AGENT_NAME,
                room=room_name,
                metadata=metadata,
            )
        )


@app.post("/token")
async def create_token(request: Request):
    try:
        body = await request.json()
    except Exception:
        body = {}

    if not isinstance(body, dict):
        body = {}

    missing_vars = _missing_livekit_env_vars()
    if missing_vars:
        raise HTTPException(
            status_code=500,
            detail=(
                "Missing required LiveKit environment variables: "
                + ", ".join(missing_vars)
            ),
        )

    room_name = body.get("room_name") or f"mila-room-{uuid.uuid4().hex[:8]}"
    participant_identity = body.get("participant_identity") or f"flutter-user-{uuid.uuid4().hex[:8]}"
    participant_name = body.get("participant_name") or "Beknazar Flutter"
    participant_source = body.get("source") or "flutter"

    try:
        await _dispatch_agent_to_room(
            room_name=room_name,
            participant_source=participant_source,
        )
    except TwirpError as error:
        raise HTTPException(
            status_code=502,
            detail=f"Could not dispatch Mila agent: {error.message or str(error)}",
        ) from error
    except Exception as error:
        raise HTTPException(
            status_code=502,
            detail=f"Could not dispatch Mila agent: {error}",
        ) from error

    token = (
        AccessToken(
            api_key=LIVEKIT_API_KEY,
            api_secret=LIVEKIT_API_SECRET,
        )
        .with_identity(participant_identity)
        .with_name(participant_name)
        .with_grants(
            VideoGrants(
                room_join=True,
                room=room_name,
                can_publish=True,
                can_subscribe=True,
                can_publish_data=True,
            )
        )
        .to_jwt()
    )

    return JSONResponse(
        status_code=201,
        content={
            "server_url": LIVEKIT_URL,
            "participant_token": token,
        },
    )


@app.get("/health")
def health():
    return {"ok": True}


@app.get("/employees")
async def employees(limit: int = 200):
    bounded_limit = max(1, min(int(limit), 500))

    try:
        items = await get_all_active_employees_data(limit=bounded_limit)
    except RuntimeError as error:
        raise HTTPException(status_code=500, detail=str(error)) from error
    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=f"Could not load employees: {error}",
        ) from error

    return {
        "employees": items,
        "count": len(items),
    }


@app.post("/telegram/staff-upload")
async def telegram_staff_upload(
    file: UploadFile = File(...),
    message: str = Form(""),
    participant_name: str = Form(""),
    participant_identity: str = Form(""),
    source: str = Form("flutter"),
):
    filename = (file.filename or "").strip() or "attachment"

    try:
        content = await file.read()
        result = await send_staff_attachment(
            filename=filename,
            content=content,
            participant_name=participant_name,
            participant_identity=participant_identity,
            participant_source=source,
            message=message,
            content_type=file.content_type,
        )
    except RuntimeError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=f"Could not send attachment to Telegram: {error}",
        ) from error

    return {
        "ok": True,
        "message": "Attachment sent to Telegram.",
        "filename": filename,
        "telegram_result": result,
    }

@app.get("/debug-env")
def debug_env():
    if not ENABLE_DEBUG_ENV:
        raise HTTPException(status_code=404, detail="Not found")

    return {
        "loaded_env_files": [str(path) for path in LOADED_ENV_FILES],
        "livekit_url_loaded": LIVEKIT_URL is not None,
        "api_key_loaded": LIVEKIT_API_KEY is not None,
        "api_secret_loaded": LIVEKIT_API_SECRET is not None,
        "livekit_url_preview": LIVEKIT_URL[:15] if LIVEKIT_URL else None,
    }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "token_server:app",
        host=os.getenv("HOST", "0.0.0.0"),
        port=env_int("PORT", 8000),
        reload=env_bool("UVICORN_RELOAD", default=False),
    )
