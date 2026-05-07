# Console Start Guide

This guide is for starting MILA from the console on Windows PowerShell.

## 1. Open PowerShell

Open PowerShell and go to the project folder:

```powershell
cd C:\Users\User\Documents\Codex\2026-05-06-files-mentioned-by-the-user-mila\MILA
```

## 2. Check whether Python is installed

Run:

```powershell
python --version
```

Use Python 3.11 or 3.12 for this project.

If your command shows Python 3.14, do not continue with that interpreter for MILA. Install Python 3.12, then reopen PowerShell and use that version instead.

If Python is missing, install Python 3.11 or 3.12 first, then reopen PowerShell.

## 3. Create a fresh virtual environment

The `.venv` inside the ZIP may be tied to another machine, so the safest option is to recreate it:

```powershell
py -3.12 -m venv .venv
```

If `py` is not available, use the full path to your Python 3.12 installation, for example:

```powershell
& "C:\Users\User\AppData\Local\Programs\Python\Python312\python.exe" -m venv .venv
```

## 4. Activate the virtual environment

Run:

```powershell
.\.venv\Scripts\Activate.ps1
```

If PowerShell blocks script execution, run this once in the same window:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Then activate again:

```powershell
.\.venv\Scripts\Activate.ps1
```

When activation works, you should see `(.venv)` at the start of the line.

## 5. Install backend dependencies

Run:

```powershell
pip install -r requirements.txt
```

If you previously saw a `protobuf` / `grpcio-status` conflict warning, the requirements file has now been corrected. The safest fix is to recreate the virtual environment and install again from the updated file.

## 6. Prepare backend environment variables

If you do not already have a working `.env.local`, copy the example:

```powershell
Copy-Item .env.example .env.local
```

Then open `.env.local` and fill in your real backend values:

- `LIVEKIT_URL`
- `LIVEKIT_API_KEY`
- `LIVEKIT_API_SECRET`
- `DATABASE_URL`
- `GOOGLE_API_KEY`
- `TELEGRAM_BOT_TOKEN`
- `TELEGRAM_STAFF_CHAT_ID`

If you are using the local Docker PostgreSQL from this project, set:

```text
DATABASE_URL=postgresql://mila:mila_strong_password_change_me@localhost:5432/mila_ai
```

Do not put these secrets into Flutter.

## 7. Start PostgreSQL with pgvector

If you use the memory and employee database features:

```powershell
docker compose up -d
```

On a fresh database, Docker now runs every SQL file from the project's `db` folder so the memory, employee, Telegram target, and pending action tables are all created together.

## 8. Start the token server

In the first PowerShell window:

```powershell
python -m uvicorn token_server:app --host 0.0.0.0 --port 8000 --reload
```

If you get `No module named uvicorn` or `uvicorn is not recognized`, install the updated dependencies again:

```powershell
pip install -r requirements.txt
```

Check it with:

```powershell
Invoke-RestMethod http://127.0.0.1:8000/health
```

You should get:

```json
{"ok": true}
```

## 9. Start the Mila agent

Open a second PowerShell window.

Go to the project again:

```powershell
cd C:\Users\User\Documents\Codex\2026-05-06-files-mentioned-by-the-user-mila\MILA
```

Activate the environment again:

```powershell
.\.venv\Scripts\Activate.ps1
```

Start the agent in development mode:

```powershell
python agent.py dev
```

For non-dev worker mode later, use:

```powershell
python agent.py start
```

## 10. Flutter app location

The Flutter client is already saved here:

```powershell
C:\Users\User\Documents\Codex\2026-05-06-files-mentioned-by-the-user-mila\MILA\mila_flutter_app
```

## 11. If you want to work on Flutter from console

Move into the app folder:

```powershell
cd C:\Users\User\Documents\Codex\2026-05-06-files-mentioned-by-the-user-mila\MILA\mila_flutter_app
```

Get packages:

```powershell
flutter pub get
```

Check the app:

```powershell
flutter analyze
flutter test
```

## 12. Important iOS note

You can prepare the Flutter code on Windows, but to run the iOS app on simulator, real iPhone, or TestFlight, you need a Mac with Xcode.

On the iPhone app, set the backend URL in Settings, for example:

```text
https://my-domain.com
```
