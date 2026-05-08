import os
import html
import mimetypes

import httpx
from env_config import load_project_env


load_project_env()

TELEGRAM_BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN")
TELEGRAM_STAFF_CHAT_ID = os.getenv("TELEGRAM_STAFF_CHAT_ID")
TELEGRAM_ATTACHMENT_MAX_BYTES = 20 * 1024 * 1024
TELEGRAM_PHOTO_MAX_BYTES = 10 * 1024 * 1024


def _check_telegram_config() -> None:
    if not TELEGRAM_BOT_TOKEN:
        raise RuntimeError("TELEGRAM_BOT_TOKEN is missing from the environment.")

    if not TELEGRAM_STAFF_CHAT_ID:
        raise RuntimeError("TELEGRAM_STAFF_CHAT_ID is missing from the environment.")


async def send_telegram_message(
    chat_id: str,
    text: str,
    disable_notification: bool = False,
) -> str:
    """
    Send a message to a Telegram chat, group, or channel.
    """

    _check_telegram_config()

    url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"

    payload = {
        "chat_id": chat_id,
        "text": text,
        "parse_mode": "HTML",
        "disable_web_page_preview": True,
        "disable_notification": disable_notification,
    }

    async with httpx.AsyncClient(timeout=20) as client:
        response = await client.post(url, json=payload)

    if response.status_code >= 400:
        return f"Telegram API HTTP error {response.status_code}: {response.text}"

    data = response.json()

    if not data.get("ok"):
        return f"Telegram API error: {data}"

    message_id = data.get("result", {}).get("message_id")

    return f"Telegram message sent successfully. message_id={message_id}"


async def send_staff_announcement(
    title: str,
    message: str,
    urgent: bool = False,
) -> str:
    """
    Send announcement to the main staff Telegram group.
    """

    _check_telegram_config()

    safe_title = html.escape(title.strip())
    safe_message = html.escape(message.strip())

    prefix = "🔴 <b>URGENT ANNOUNCEMENT</b>" if urgent else "📢 <b>ANNOUNCEMENT</b>"

    final_text = f"""{prefix}

<b>{safe_title}</b>

{safe_message}
"""

    return await send_telegram_message(
        chat_id=TELEGRAM_STAFF_CHAT_ID,
        text=final_text,
        disable_notification=False,
    )

async def send_private_telegram_message(
    chat_id: str,
    title: str,
    message: str,
    urgent: bool = False,
) -> str:
    """
    Send a private Telegram message to one employee by private chat_id.
    """

    if not chat_id:
        raise RuntimeError("telegram_chat_id is missing.")

    safe_title = html.escape(title.strip())
    safe_message = html.escape(message.strip())

    prefix = "🔴 <b>URGENT MESSAGE</b>" if urgent else "📩 <b>PRIVATE MESSAGE</b>"

    final_text = f"""{prefix}

<b>{safe_title}</b>

{safe_message}
"""

    return await send_telegram_message(
        chat_id=chat_id,
        text=final_text,
        disable_notification=False,
    )


def _guess_content_type(filename: str, content_type: str | None) -> str:
    if content_type:
        return content_type

    guessed_type, _ = mimetypes.guess_type(filename)
    if guessed_type:
        return guessed_type

    return "application/octet-stream"


def _build_attachment_caption(
    participant_name: str,
    participant_identity: str,
    participant_source: str,
    message: str,
) -> str:
    lines = ["<b>MILA APP ATTACHMENT</b>"]

    safe_name = html.escape(participant_name.strip())
    safe_identity = html.escape(participant_identity.strip())
    safe_source = html.escape(participant_source.strip())
    safe_message = html.escape(message.strip())

    if safe_name:
        lines.append(f"From: {safe_name}")
    elif safe_identity:
        lines.append(f"From: {safe_identity}")

    if safe_source:
        lines.append(f"Source: {safe_source}")

    if safe_message:
        lines.extend(("", safe_message))

    caption = "\n".join(lines).strip()
    if len(caption) <= 900:
        return caption

    return f"{caption[:897].rstrip()}..."


async def _send_telegram_file(
    *,
    chat_id: str,
    method: str,
    field_name: str,
    filename: str,
    content: bytes,
    content_type: str,
    caption: str,
) -> str:
    _check_telegram_config()

    url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/{method}"
    data = {
        "chat_id": chat_id,
        "caption": caption,
        "parse_mode": "HTML",
        "disable_notification": False,
    }
    files = {
        field_name: (
            filename,
            content,
            content_type,
        ),
    }

    async with httpx.AsyncClient(timeout=60) as client:
        response = await client.post(url, data=data, files=files)

    if response.status_code >= 400:
        return f"Telegram API HTTP error {response.status_code}: {response.text}"

    data = response.json()

    if not data.get("ok"):
        return f"Telegram API error: {data}"

    message_id = data.get("result", {}).get("message_id")
    return f"Telegram attachment sent successfully. message_id={message_id}"


async def send_staff_attachment(
    *,
    filename: str,
    content: bytes,
    participant_name: str = "",
    participant_identity: str = "",
    participant_source: str = "",
    message: str = "",
    content_type: str | None = None,
) -> str:
    _check_telegram_config()

    safe_filename = filename.strip() or "attachment"
    resolved_content_type = _guess_content_type(safe_filename, content_type)

    if not content:
        raise RuntimeError("Uploaded file is empty.")

    if len(content) > TELEGRAM_ATTACHMENT_MAX_BYTES:
        raise RuntimeError("Attachment is too large. Please keep uploads under 20 MB.")

    caption = _build_attachment_caption(
        participant_name=participant_name,
        participant_identity=participant_identity,
        participant_source=participant_source,
        message=message,
    )

    send_as_photo = (
        resolved_content_type.startswith("image/")
        and len(content) <= TELEGRAM_PHOTO_MAX_BYTES
    )

    if send_as_photo:
        result = await _send_telegram_file(
            chat_id=TELEGRAM_STAFF_CHAT_ID,
            method="sendPhoto",
            field_name="photo",
            filename=safe_filename,
            content=content,
            content_type=resolved_content_type,
            caption=caption,
        )
        if "successfully" in result:
            return result

    return await _send_telegram_file(
        chat_id=TELEGRAM_STAFF_CHAT_ID,
        method="sendDocument",
        field_name="document",
        filename=safe_filename,
        content=content,
        content_type=resolved_content_type,
        caption=caption,
    )
