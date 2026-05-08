import asyncio
import json
import os
from datetime import datetime, timezone

from pydantic import BaseModel, Field

from employee_service import (
    init_employee_pool,
    list_departments,
    find_employee,
    get_employee_by_number,
    get_employee_private_chat_data,
    list_department_employees,
    list_all_active_employees,
    list_telegram_targets,
    get_telegram_target,
)

from action_service import (
    init_action_pool,
    create_pending_action,
    list_pending_actions,
    execute_latest_pending_action,
    cancel_latest_pending_action,
)
from livekit.agents import (
    Agent,
    AgentServer,
    AgentSession,
    JobContext,
    RunContext,
    WorkerOptions,
    cli,
    function_tool,
    room_io,
)
from livekit.agents.llm import ChatContext

from memory_service import (
    init_memory_pool,
    get_startup_memory,
    save_memory,
    search_memory,
    forget_memory,
    list_recent_memory,
)

from livekit.plugins import google
from telegram_service import send_staff_announcement
from env_config import env_int, load_project_env

load_project_env()


def _env_float(name: str, default: float) -> float:
    raw_value = os.getenv(name)
    if raw_value is None or not raw_value.strip():
        return default
    return float(raw_value)


MILA_REALTIME_MODEL = (
    os.getenv("MILA_REALTIME_MODEL", "gemini-3.1-flash-live-preview").strip()
    or "gemini-3.1-flash-live-preview"
)
MILA_TEXT_MODEL = (
    os.getenv("MILA_TEXT_MODEL", "gemini-2.5-flash").strip()
    or "gemini-2.5-flash"
)
MILA_TEXT_TEMPERATURE = _env_float("MILA_TEXT_TEMPERATURE", 0.5)
MILA_TEXT_MAX_OUTPUT_TOKENS = env_int("MILA_TEXT_MAX_OUTPUT_TOKENS", 700)
MILA_STARTUP_MEMORY_LIMIT = env_int("MILA_STARTUP_MEMORY_LIMIT", 8)
MILA_STARTUP_MEMORY_TIMEOUT_SECONDS = _env_float(
    "MILA_STARTUP_MEMORY_TIMEOUT_SECONDS",
    1.5,
)
MILA_AEC_WARMUP_SECONDS = _env_float("MILA_AEC_WARMUP_SECONDS", 1.0)
MILA_MEMORY_SUMMARY_MODEL = (
    os.getenv("MILA_MEMORY_SUMMARY_MODEL", "gemini-2.5-flash").strip()
    or "gemini-2.5-flash"
)
MILA_AUTO_MEMORY_MAX_MESSAGES = env_int("MILA_AUTO_MEMORY_MAX_MESSAGES", 24)
MILA_AUTO_MEMORY_MAX_CHARS = env_int("MILA_AUTO_MEMORY_MAX_CHARS", 12000)
MILA_AUTO_MEMORY_WAIT_SECONDS = _env_float("MILA_AUTO_MEMORY_WAIT_SECONDS", 6.0)

SYSTEM_PROMPT = """
You are Mila, a personal AI assistant for the CEO of a textile and light-industry company based in Uzbekistan named "Milana premium".

The CEOs name is Beknazar.

The company operates in the light manufacturing industry, mainly producing knitwear and womens pajamas. The business includes production, sales, purchasing, warehouse operations, innovations operation, administration, employee coordination, and daily management tasks.

Your main role is to support the CEO in everyday work, help control company processes, organize tasks, analyze information, and assist with operational decision-making.

PERSONALITY AND COMMUNICATION STYLE

You are Mila, a young female AI assistant with an elegant, friendly, slightly playful, and beautiful communication style.

You should sound warm, intelligent, attentive, and professional. Your tone may be light and pleasant, but you must always stay respectful, useful, and business-focused.

You should not be overly emotional, childish, flirtatious, or informal in business situations.

You are allowed to express personality, but your priority is always clarity, accuracy, discipline, and usefulness.

LANGUAGE RULES

Your default language is Russian.

If the user writes or speaks in another language, switch to that language naturally.

You may communicate in Russian, English, Uzbek, Kazakh, Kyrgyz, or other languages when needed.

If the user mixes languages, answer in the language that is most useful and natural for the situation.

MAIN RESPONSIBILITIES

You help the CEO with:

1. Daily task management
- Create, organize, and prioritize daily tasks.
- Remind the CEO what needs attention.
- Break complex tasks into clear steps.
- Track unfinished tasks and suggest next actions.

2. Company control
- Help monitor production, sales, purchasing, warehouse, innovations, employees, and administrative processes.
- Ask for missing data when necessary.
- Summarize the current status of departments.
- Detect delays, risks, missing information, and weak points.

3. Sales support
- Help analyze sales performance.
- Prepare messages for clients and partners.
- Support wholesale and retail communication.
- Help structure offers, catalogs, price lists, and commercial proposals.
- Track client requests, orders, objections, and follow-ups.

4. Purchasing support
- Help organize supplier communication.
- Compare supplier offers when data is provided.
- Track purchasing tasks, fabric orders, accessories, packaging, and production materials.
- Help identify urgent purchasing issues that may affect production.

5. Production support
- Help the CEO control production stages.
- Work with information about models, fabrics, sizes, colors, quantities, deadlines, and defects.
- Help identify bottlenecks in cutting, sewing, packing, warehouse, or shipment.
- Suggest structured production checklists.

6. Administrative support
- Help prepare internal instructions, reports, meeting notes, and task lists.
- Support communication with managers and employees.
- Help formulate clear assignments for department heads.
- Help convert unclear instructions into structured tasks.

7. Decision support
- Analyze provided information logically.
- Identify what is known, what is missing, and what needs confirmation.
- Give practical recommendations.
- Do not invent facts, numbers, results, or events.

8. Memory and context
- Remember important business context when memory is available.
- Track repeated tasks, preferences, company rules, and CEO priorities.
- When unsure, ask a clarification question instead of assuming.

EMPLOYEE DATABASE RULES

You have access to the company employee database.

Use the employee database for:
- departments;
- employee names;
- positions;
- Telegram usernames;
- Telegram group targets;
- department communication.

Do not store employee lists only in memory.
Employees and Telegram targets must be stored in the employee database.

When the CEO asks to add an employee, collect:
- full name;
- department;
- position;
- phone if available;
- Telegram username if available;
- access level if needed.

When the CEO asks to message a department, use Telegram targets, not memory.
If the target group is not configured, say that the Telegram target is missing.

LANGUAGE SWITCHING RULES

Default language: Russian.

If the CEO or user speaks Uzbek, immediately switch to Uzbek and respond in Uzbek.

Support both Uzbek Latin and Uzbek Cyrillic.

For Uzbek communication:
- respond naturally in Uzbek;
- use Uzbek Latin by default;
- keep the tone professional, polite, and clear;
- do not switch back to Russian unless the user switches back to Russian;
- if the user mixes Russian and Uzbek, answer in the language that dominates the request;
- if the user asks in Uzbek, never stay silent — answer briefly even if the request is unclear.

If speech recognition is unclear, say in Uzbek:
"Kechirasiz, aniq eshitmadim. Iltimos, qayta ayting."

The assistant must be able to communicate in:
Russian, Uzbek, English, Kyrgyz, Kazakh.

BEHAVIOR RULES

Always be precise and structured.

Do not invent data.

If you do not know something, say that you do not know.

If information is incomplete, clearly say what is missing.

Separate facts from assumptions.

When giving recommendations, explain the reasoning briefly.

When the CEO gives a task, respond with:
- what you understood;
- what needs to be done;
- the next clear action.

When a task is complex, divide it into stages.

When a task is urgent, prioritize speed and clarity.

When a task involves another employee or department, help formulate a clear message or instruction.

You must help the CEO stay organized, focused, and in control of the company.

RESPONSE FORMAT

For business tasks, use a clear structure:

1. Summary
2. Key points
3. Recommended action
4. Next step

For simple questions, answer directly and briefly.

For messages, letters, instructions, or scripts, write ready-to-use text.

For analysis, use tables or bullet points when useful.

COMPANY CONTEXT

Company location: Uzbekistan.

Industry: light industry, textile production, knitwear, pajamas, womens homewear and sleepwear.

Main business focus: production and sale of womens pajamas and related knitwear products.

The assistant must understand that the company works with production, sales, purchases, warehouse, innovations, management, and daily operational control.

IMPORTANT LIMITATIONS

You are an AI assistant, not a real human employee.

Do not claim that you physically visited the factory, contacted someone, made a call, sent a message, or completed an offline action unless a connected tool actually confirms it.

Do not promise future work unless a real scheduling or automation tool is available.

Do not make legal, financial, or production-critical decisions without asking for confirmation from the CEO.

Your job is to assist, organize, analyze, write, explain, and support the CEOs control over the business.

CORE IDENTITY

Your name is Mila.

You are the personal AI assistant of Beknazar.

You are elegant, smart, slightly playful, professional, and highly organized.

Your mission is to help the CEO manage daily work, control the company, improve communication, and make business processes clearer and more efficient.

TELEGRAM CONTROL RULES

You can send company announcements to the staff Telegram group using the Telegram announcement tool.

When the CEO asks you to notify employees, send an announcement, or inform the team:

1. First, prepare a clear message draft.
2. Read or show the message to the CEO.
3. Ask for explicit confirmation before sending.
4. Only after the CEO clearly confirms, use the Telegram announcement tool.

Never send mass Telegram messages without CEO confirmation.

For urgent messages, mark urgent=true only if the CEO says it is urgent or the situation clearly requires urgent attention.

Telegram messages must be:
- clear;
- professional;
- short;
- respectful;
- without unnecessary emotional language.

Default language for internal company Telegram messages: Russian.

ACTION CONFIRMATION RULES

You have access to an Action Layer.

For any real external action, you must follow this sequence:

1. Prepare the action.
2. Show the draft to the CEO.
3. Ask for explicit confirmation.
4. Execute only after confirmation.

External actions include:
- sending Telegram messages;
- assigning tasks;
- notifying employees;
- changing schedules;
- sending reports;
- creating future calendar events.

Never execute an external action in the same step where the CEO first requests it.

For Telegram announcements:
- First use prepare_telegram_staff_announcement.
- Then ask: "Подтверждаете отправку?"
- Only after the CEO confirms, use confirm_latest_pending_action.

If the CEO cancels, use cancel_latest_action.

Default language for staff Telegram messages: Russian.

EEMPLOYEE DATABASE RULES

You have access to the company employee database.

Employee records are maintained manually through CSV import.
Do not create, edit, or delete employees by voice command.

You may only:
- show departments;
- search employees;
- show employees by employee number;
- show employees by department;
- show all active employees;
- show Telegram targets.

If the CEO asks to add, edit, or delete an employee, respond:
"Для точности сотрудников лучше изменить вручную через CSV-файл и затем запустить импорт."

Use employee_no as the main human-readable employee number.
Do not treat database UUID as employee number.

"""

class AutoMemoryDraft(BaseModel):
    should_save: bool = False
    title: str = ""
    summary: str = ""
    category: str = "conversation"
    memory_type: str = "session_summary"
    importance: int = Field(default=3, ge=1, le=5)
    tags: list[str] = Field(default_factory=list)


class Assistant(Agent):
    def __init__(self, startup_memory: str = "") -> None:
        memory_rules = f"""

LONG-TERM MEMORY CONTEXT

You have access to production long-term memory.

Important saved memory:

{startup_memory}

MEMORY RULES

Use memory carefully and professionally.

When the CEO says:
- "запомни"
- "сохрани"
- "remember"
- "note this"
- "keep this in memory"

you must save the information using the remember_business_fact tool.

Save only useful long-term business information:
- CEO preferences
- company rules
- employee roles
- supplier information
- client preferences
- sales rules
- purchasing rules
- production rules
- warehouse rules
- innovations rules
- recurring management tasks

Do not save:
- passwords
- API keys
- private keys
- bank card data
- temporary random details
- sensitive personal data unless the CEO clearly requests it.

When you need old context, use search_business_memory.

When the CEO asks about:
- previous calls;
- past conversations;
- what was discussed earlier;
- what was seen earlier through the camera;
- earlier instructions or decisions;

use search_business_memory before answering if the answer depends on prior sessions.

When the CEO asks what you remember, use list_memory.

When the CEO asks to forget something, use forget_business_memory.

TELEGRAM CONTROL RULES

You can send company announcements to the staff Telegram group using the Telegram announcement tool.

When the CEO asks you to notify employees, send an announcement, or inform the team:

1. First, prepare a clear message draft.
2. Read or show the message to the CEO.
3. Ask for explicit confirmation before sending.
4. Only after the CEO clearly confirms, use the Telegram announcement tool.

Never send mass Telegram messages without CEO confirmation.

Default language for internal Telegram messages: Russian.

Always separate remembered facts from assumptions.

PERSONAL TELEGRAM MESSAGE RULES

When the CEO asks to send a message to one specific employee, do not use the staff group announcement tool.

Use prepare_personal_telegram_message when:
- the CEO mentions one employee;
- the CEO gives an employee number;
- the CEO says "send personally";
- the CEO says "send private message";
- the CEO says "напиши лично сотруднику";
- the CEO says "отправь лично".

For personal Telegram messages:
1. Find or use the employee_no.
2. Prepare the private message using prepare_personal_telegram_message.
3. Ask for explicit CEO confirmation.
4. Only after confirmation, execute the latest pending action.

For messages to all employees or departments, use group or broadcast tools, not the personal employee tool.
"""

        super().__init__(
            instructions=SYSTEM_PROMPT + memory_rules,
            tools=[
                google.tools.GoogleSearch(),
            ],
        )

    @function_tool()
    async def prepare_personal_telegram_message(
        self,
        context: RunContext,
        employee_no: int,
        title: str,
        message: str,
        urgent: bool = False,
    ) -> str:
        employee = await get_employee_private_chat_data(employee_no=employee_no)
        """
        Prepare a private Telegram message for one employee by employee number.
        This tool only creates a pending action.
        It does not send immediately.
        After preparing, ask the CEO for explicit confirmation.
        """

        if not employee.get("ok"):
            return employee.get("error", "Could not prepare private Telegram message.")

        payload = {
            "employee_no": employee["employee_no"],
            "full_name": employee["full_name"],
            "chat_id": employee["telegram_chat_id"],
            "title": title,
            "message": message,
            "urgent": urgent,
        }

        action_id = await create_pending_action(
            action_type="telegram_employee_private_message",
            target=f"employee:{employee['employee_no']}",
            payload=payload,
        )

        return (
            "Private Telegram message prepared and waiting for CEO confirmation.\n\n"
            f"Action ID: {action_id}\n"
            f"Employee: #{employee['employee_no']} {employee['full_name']}\n"
            f"Telegram username: {employee.get('telegram_username')}\n"
            f"Title: {title}\n"
            f"Message: {message}\n"
            f"Urgent: {urgent}\n\n"
            "Ask the CEO: Подтверждаете отправку личного сообщения?"
        )

    @function_tool()
    async def remember_business_fact(
        self,
        context: RunContext,
        title: str,
        content: str,
        category: str = "general",
        memory_type: str = "fact",
        importance: int = 3,
    ) -> str:
        """
        Save important long-term business memory about the CEO, company, employees,
        clients, suppliers, sales, purchases, production, warehouse, innovations, or management rules.
        Do not save secrets, passwords, private keys, API keys, or temporary random information.
        """
        return await save_memory(
            title=title,
            content=content,
            category=category,
            memory_type=memory_type,
            importance=importance,
        )

    @function_tool()
    async def search_business_memory(
        self,
        context: RunContext,
        query: str,
        limit: int = 5,
    ) -> str:
        """
        Search long-term business memory by meaning.
        Use this when old company context, CEO preferences, employee roles,
        supplier information, client preferences, or business rules may be useful.
        """
        return await search_memory(query=query, limit=limit)
    
    @function_tool()
    async def list_memory(
        self,
        context: RunContext,
        limit: int = 10,
    ) -> str:
        """
        List recent saved long-term memories.
        Use this when the CEO asks what you remember.
        """
        return await list_recent_memory(limit=limit)

    @function_tool()
    async def forget_business_memory(
        self,
        context: RunContext,
        keyword: str,
    ) -> str:
        """
        Soft-delete saved memory by keyword.
        Use this only when the CEO asks to forget or remove something from memory.
        """
        return await forget_memory(keyword=keyword)

    @function_tool()
    async def send_telegram_staff_announcement(
        self,
        context: RunContext,
        title: str,
        message: str,
        urgent: bool = False,
    ) -> str:
        """
        Prepare a Telegram announcement for the staff group.
        This tool only creates a pending action.
        It does not send the message.
        After preparing, ask the CEO for explicit confirmation.
        """

        payload = {
            "title": title,
            "message": message,
            "urgent": urgent,
        }

        action_id = await create_pending_action(
            action_type="telegram_staff_announcement",
            target="staff_telegram_group",
            payload=payload,
        )

        return (
            "Telegram announcement prepared and waiting for CEO confirmation.\n\n"
            f"Action ID: {action_id}\n"
            f"Title: {title}\n"
            f"Message: {message}\n"
            f"Urgent: {urgent}\n\n"
            "Ask the CEO: Подтверждаете отправку?"
        )

    @function_tool()
    async def confirm_latest_pending_action(
        self,
        context: RunContext,
        confirmation_text: str,
    ) -> str:
        """
        Execute the latest pending action only after the CEO clearly confirms.
        Use this only when the CEO says something like:
        'да, отправь', 'подтверждаю', 'отправляй', 'yes, send it'.
        """

        return await execute_latest_pending_action(
            confirmation_text=confirmation_text,
        )
     
    @function_tool()    
    async def show_departments(
        self,
        context: RunContext,
    ) -> str:
        """
        Show all active company departments.
        """
        return await list_departments()

    @function_tool()
    async def search_employee(
        self,
        context: RunContext,
        query: str,
    ) -> str:
        """
        Search employees by employee number, name, short name, position, phone, or Telegram username.
        """
        return await find_employee(query=query)

    @function_tool()
    async def show_employee_by_number(
        self,
        context: RunContext,
        employee_no: int,
    ) -> str:
        """
        Show one employee by employee number.
        """
        return await get_employee_by_number(employee_no=employee_no)

    @function_tool()
    async def show_department_employees(
        self,
        context: RunContext,
        department_key: str,
    ) -> str:
        """
        Show active employees from a specific department.
        """
        return await list_department_employees(department_key=department_key)

    @function_tool()
    async def show_all_active_employees(
        self,
        context: RunContext,
        limit: int = 200,
    ) -> str:
        """
        Show all active employees.
        """
        return await list_all_active_employees(limit=limit)

    @function_tool()
    async def show_telegram_targets(
        self,
        context: RunContext,
    ) -> str:
        """
        Show all configured Telegram targets.
        """
        return await list_telegram_targets()

    @function_tool()
    async def show_telegram_target(
        self,
        context: RunContext,
        target_key: str,
    ) -> str:
        """
        Show one Telegram target by target_key.
        """
        return await get_telegram_target(target_key=target_key)


def _clip_text(value: str, limit: int) -> str:
    text = value.strip()
    if len(text) <= limit:
        return text
    return text[: max(0, limit - 3)].rstrip() + "..."


def _instructions_to_text(value: str | object) -> str:
    if isinstance(value, str):
        return value
    return str(value)


def _message_has_content_type(message, content_type: str) -> bool:
    for content_item in getattr(message, "content", []):
        if getattr(content_item, "type", None) == content_type:
            return True
    return False


def _render_history_for_memory(chat_ctx: ChatContext) -> tuple[str, bool, int]:
    rendered_messages: list[str] = []
    had_vision = False

    for item in chat_ctx.items:
        if getattr(item, "type", None) != "message":
            continue

        role = getattr(item, "role", None)
        if role not in {"user", "assistant"}:
            continue

        text_content = (getattr(item, "text_content", None) or "").strip()
        has_image = _message_has_content_type(item, "image_content")
        has_audio = _message_has_content_type(item, "audio_content")

        lines: list[str] = []
        if text_content:
            lines.append(text_content)
        if has_image:
            had_vision = True
            lines.append("[visual context was present in this turn]")
        if has_audio and not text_content:
            lines.append("[audio was present but no transcript text was captured]")

        if not lines:
            continue

        rendered_messages.append(f"<{role}>{' '.join(lines)}</{role}>")

    if not rendered_messages:
        return "", had_vision, 0

    recent_messages = rendered_messages[-MILA_AUTO_MEMORY_MAX_MESSAGES :]
    transcript = _clip_text("\n".join(recent_messages), MILA_AUTO_MEMORY_MAX_CHARS)
    return transcript, had_vision, len(recent_messages)


async def _generate_text_reply_with_secondary_model(
    *,
    text_llm: google.LLM,
    instructions: str | object,
    session_history: ChatContext,
    user_text: str,
) -> str:
    chat_ctx = ChatContext.empty()
    chat_ctx.add_message(
        role="system",
        content=_instructions_to_text(instructions),
    )

    history_excerpt, had_vision, _ = _render_history_for_memory(session_history)
    if history_excerpt:
        chat_ctx.add_message(
            role="system",
            content=(
                "Recent conversation context from this room:\n"
                f"{history_excerpt}"
            ),
        )
    if had_vision:
        chat_ctx.add_message(
            role="system",
            content=(
                "Camera/video context was present in earlier turns. "
                "If needed, mention uncertainty and ask a clarifying question."
            ),
        )

    chat_ctx.add_message(role="user", content=user_text)

    chunks: list[str] = []
    async with text_llm.chat(chat_ctx=chat_ctx) as stream:
        async for chunk in stream:
            if chunk.delta and chunk.delta.content:
                chunks.append(chunk.delta.content)

    reply = "".join(chunks).strip()
    if reply:
        return reply

    return "Извините, не получилось сформировать ответ на текст. Повторите, пожалуйста."


def _normalize_memory_tags(*tag_groups: list[str] | tuple[str, ...]) -> list[str]:
    normalized: list[str] = []
    seen: set[str] = set()

    for group in tag_groups:
        for tag in group:
            clean_tag = str(tag).strip().lower().replace(" ", "-")
            if not clean_tag:
                continue
            clean_tag = clean_tag[:48]
            if clean_tag in seen:
                continue
            seen.add(clean_tag)
            normalized.append(clean_tag)

    return normalized


def _default_session_memory_title(had_vision: bool) -> str:
    prefix = "Vision session" if had_vision else "Conversation session"
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    return f"{prefix} {timestamp}"


def _fallback_memory_summary(transcript: str) -> str:
    plain_lines: list[str] = []

    for line in transcript.splitlines():
        clean_line = line.strip()
        if clean_line.startswith("<user>") and clean_line.endswith("</user>"):
            plain_lines.append(f"User: {clean_line[6:-7].strip()}")
        elif clean_line.startswith("<assistant>") and clean_line.endswith("</assistant>"):
            plain_lines.append(f"Assistant: {clean_line[11:-12].strip()}")

    if not plain_lines:
        return transcript

    return "\n".join(plain_lines[-8:])


async def _draft_session_memory(
    transcript: str,
    had_vision: bool,
) -> AutoMemoryDraft | None:
    chat_ctx = ChatContext.empty()
    chat_ctx.add_message(
        role="system",
        content=(
            "You prepare durable long-term memory for Mila. "
            "Return JSON only. Save concise, factual business context from the session. "
            "Focus on decisions, preferences, commitments, follow-ups, people, production facts, "
            "sales facts, purchasing facts, and important visual observations that were explicitly "
            "discussed or confirmed during the session. "
            "Do not save greetings, filler, passwords, API keys, private keys, bank data, or random noise. "
            "If the session had no durable information, set should_save=false."
        ),
    )
    chat_ctx.add_message(
        role="user",
        content=(
            f"Vision context present: {'yes' if had_vision else 'no'}\n\n"
            f"Session transcript:\n{transcript}"
        ),
    )

    summarizer = google.LLM(
        model=MILA_MEMORY_SUMMARY_MODEL,
        temperature=0.2,
        max_output_tokens=500,
    )

    chunks: list[str] = []
    async with summarizer.chat(
        chat_ctx=chat_ctx,
        response_format=AutoMemoryDraft,
    ) as stream:
        async for chunk in stream:
            if chunk.delta and chunk.delta.content:
                chunks.append(chunk.delta.content)

    raw_response = "".join(chunks).strip()
    if not raw_response:
        return None

    try:
        return AutoMemoryDraft.model_validate_json(raw_response)
    except Exception:
        try:
            return AutoMemoryDraft.model_validate(json.loads(raw_response))
        except Exception as error:
            print(f"WARNING: failed to parse automatic memory summary: {error}")
            return None


async def _persist_session_memory(chat_ctx: ChatContext, close_reason: str) -> None:
    transcript, had_vision, message_count = _render_history_for_memory(chat_ctx)
    if message_count < 2 or not transcript:
        return

    draft: AutoMemoryDraft | None = None
    try:
        draft = await asyncio.wait_for(
            _draft_session_memory(transcript, had_vision),
            timeout=MILA_AUTO_MEMORY_WAIT_SECONDS,
        )
    except asyncio.TimeoutError:
        print(
            "WARNING: automatic memory summary timed out after "
            f"{MILA_AUTO_MEMORY_WAIT_SECONDS:.1f}s"
        )
    except Exception as error:
        print(f"WARNING: failed to summarize automatic memory: {error}")

    if draft is None:
        draft = AutoMemoryDraft(
            should_save=True,
            title=_default_session_memory_title(had_vision),
            summary=_fallback_memory_summary(transcript),
            category="vision" if had_vision else "conversation",
            memory_type="session_summary",
            importance=3,
            tags=["auto-memory", "session"],
        )

    if not draft.should_save:
        if had_vision or message_count >= 4:
            draft = AutoMemoryDraft(
                should_save=True,
                title=_default_session_memory_title(had_vision),
                summary=_fallback_memory_summary(transcript),
                category="vision" if had_vision else "conversation",
                memory_type="session_summary",
                importance=3,
                tags=["auto-memory", "session"],
            )
        else:
            return

    title = draft.title.strip() or _default_session_memory_title(had_vision)
    summary = draft.summary.strip() or _fallback_memory_summary(transcript)
    category = draft.category.strip() or ("vision" if had_vision else "conversation")
    memory_type = draft.memory_type.strip() or "session_summary"
    importance = max(1, min(int(draft.importance), 5))
    tags = _normalize_memory_tags(
        draft.tags,
        ["auto-memory", "session", close_reason],
        ["vision"] if had_vision else ["conversation"],
    )

    save_result = await save_memory(
        title=title,
        content=summary,
        category=category,
        memory_type=memory_type,
        importance=importance,
        tags=tags,
        source="auto_session_memory",
    )
    print(f"INFO: {save_result}")


def _install_session_memory_autosave(session: AgentSession, ctx: JobContext) -> None:
    memory_task: asyncio.Task | None = None
    memory_task_started = asyncio.Event()

    def _on_session_close(event) -> None:
        nonlocal memory_task

        if memory_task is not None:
            return

        close_reason = getattr(getattr(event, "reason", None), "value", "unknown")
        history_snapshot = session.history.copy()

        async def _runner() -> None:
            try:
                await _persist_session_memory(history_snapshot, close_reason)
            except Exception as error:
                print(f"WARNING: failed to persist automatic memory: {error}")

        memory_task = asyncio.create_task(_runner(), name="mila_auto_memory")
        memory_task_started.set()

    session.on("close", _on_session_close)

    async def _await_auto_memory(_: str) -> None:
        if memory_task is None:
            try:
                await asyncio.wait_for(
                    memory_task_started.wait(),
                    timeout=MILA_AUTO_MEMORY_WAIT_SECONDS,
                )
            except asyncio.TimeoutError:
                return

        if memory_task is not None:
            await memory_task

    ctx.add_shutdown_callback(_await_auto_memory)


server = AgentServer()


async def _load_startup_memory() -> str:
    await init_memory_pool()

    try:
        return await asyncio.wait_for(
            get_startup_memory(limit=MILA_STARTUP_MEMORY_LIMIT),
            timeout=MILA_STARTUP_MEMORY_TIMEOUT_SECONDS,
        )
    except asyncio.TimeoutError:
        print(
            "WARNING: startup memory load timed out after "
            f"{MILA_STARTUP_MEMORY_TIMEOUT_SECONDS:.1f}s"
        )
    except Exception as error:
        print(f"WARNING: failed to load startup memory: {error}")

    return ""


@server.rtc_session(agent_name="mila-agent")
async def entrypoint(ctx: JobContext):
    startup_memory, _, _, _ = await asyncio.gather(
        _load_startup_memory(),
        init_action_pool(),
        init_employee_pool(),
        ctx.connect(),
    )

    assistant = Assistant(startup_memory=startup_memory)
    text_llm = google.LLM(
        model=MILA_TEXT_MODEL,
        temperature=MILA_TEXT_TEMPERATURE,
        max_output_tokens=MILA_TEXT_MAX_OUTPUT_TOKENS,
    )
    text_turn_lock = asyncio.Lock()

    async def _text_input_cb(
        sess: AgentSession,
        ev: room_io.TextInputEvent,
    ) -> None:
        user_text = ev.text.strip()
        if not user_text:
            return

        async with text_turn_lock:
            history_snapshot = sess.history.copy()
            try:
                reply_text = await _generate_text_reply_with_secondary_model(
                    text_llm=text_llm,
                    instructions=assistant.instructions,
                    session_history=history_snapshot,
                    user_text=user_text,
                )
            except Exception as error:
                print(f"WARNING: text fallback model failed: {error}")
                reply_text = (
                    "Извините, не получилось обработать текст сейчас. "
                    "Попробуйте еще раз."
                )

            await sess.interrupt()
            sess.say(reply_text, add_to_chat_ctx=True)

    session = AgentSession(
        llm=google.realtime.RealtimeModel(
            model=MILA_REALTIME_MODEL,
            voice="Achernar",
            temperature=0.8,
        ),
        aec_warmup_duration=MILA_AEC_WARMUP_SECONDS,
    )
    _install_session_memory_autosave(session, ctx)

    await session.start(
        agent=assistant,
        room=ctx.room,
        room_options=room_io.RoomOptions(
            video_input=True,
            text_input=room_io.TextInputOptions(text_input_cb=_text_input_cb),
            text_output=True,
        ),
    )

if __name__ == "__main__":
    cli.run_app(server)
