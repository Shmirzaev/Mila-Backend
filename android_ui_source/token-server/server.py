import json
import os
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any

from dotenv import load_dotenv
from livekit import api


ROOT = Path(__file__).resolve().parent
load_dotenv(ROOT / ".env.local")

HOST = "0.0.0.0"
PORT = int(os.getenv("TOKEN_SERVER_PORT", "8787"))


def create_token_response(body: dict[str, Any]) -> dict[str, str]:
    api_key = os.getenv("LIVEKIT_API_KEY")
    api_secret = os.getenv("LIVEKIT_API_SECRET")
    server_url = os.getenv("LIVEKIT_URL")

    if not all([api_key, api_secret, server_url]):
        raise RuntimeError("Missing LiveKit server configuration in token-server/.env.local")

    room_name = body.get("room_name") or f"mila-room-{uuid.uuid4().hex[:8]}"
    participant_identity = body.get("participant_identity") or f"android-user-{uuid.uuid4().hex[:8]}"
    participant_name = body.get("participant_name") or os.getenv("DEFAULT_PARTICIPANT_NAME", "Beknazar Android")
    participant_metadata = body.get("participant_metadata")
    participant_attributes = body.get("participant_attributes")
    room_config = body.get("room_config")

    token = (
        api.AccessToken(api_key, api_secret)
        .with_identity(participant_identity)
        .with_name(participant_name)
        .with_grants(
            api.VideoGrants(
                room_join=True,
                room=room_name,
                can_publish=True,
                can_subscribe=True,
                can_publish_data=True,
            )
        )
    )

    if participant_metadata:
        token = token.with_metadata(participant_metadata)

    if participant_attributes:
        token = token.with_attributes(participant_attributes)

    if room_config:
        # LiveKit client SDKs package agent dispatch into room_config automatically.
        token = token.with_room_config(room_config)

    return {
        "server_url": server_url,
        "participant_token": token.to_jwt(),
    }


class TokenRequestHandler(BaseHTTPRequestHandler):
    server_version = "MilaTokenServer/1.0"

    def _set_headers(self, status_code: int) -> None:
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.end_headers()

    def _write_json(self, status_code: int, payload: dict[str, Any]) -> None:
        self._set_headers(status_code)
        self.wfile.write(json.dumps(payload).encode("utf-8"))

    def _read_json_body(self) -> dict[str, Any]:
        content_length = int(self.headers.get("Content-Length", "0"))
        if content_length == 0:
            return {}
        raw_body = self.rfile.read(content_length).decode("utf-8")
        return json.loads(raw_body) if raw_body else {}

    def do_OPTIONS(self) -> None:
        self._set_headers(204)

    def do_GET(self) -> None:
        if self.path in ("/", "/health"):
            self._write_json(
                200,
                {
                    "ok": True,
                    "service": "mila-token-server",
                    "token_endpoint": "/token",
                    "port": PORT,
                },
            )
            return

        self._write_json(404, {"error": "Not found"})

    def do_POST(self) -> None:
        if self.path != "/token":
            self._write_json(404, {"error": "Not found"})
            return

        try:
            body = self._read_json_body()
            response = create_token_response(body)
            self._write_json(201, response)
        except json.JSONDecodeError:
            self._write_json(400, {"error": "Invalid JSON body"})
        except Exception as exc:
            self._write_json(500, {"error": str(exc)})


if __name__ == "__main__":
    print(f"MILA token server listening on http://127.0.0.1:{PORT}")
    print("Android emulator endpoint: http://10.0.2.2:8787/token")
    ThreadingHTTPServer((HOST, PORT), TokenRequestHandler).serve_forever()
