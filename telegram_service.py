import os
import html

import httpx
from env_config import load_project_env


load_project_env()

TELEGRAM_BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN")
TELEGRAM_STAFF_CHAT_ID = os.getenv("TELEGRAM_STAFF_CHAT_ID")


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
