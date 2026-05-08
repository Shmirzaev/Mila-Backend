
# MILA

MILA is a Python backend for a LiveKit AI voice assistant plus a Flutter client in [`mila_flutter_app`](./mila_flutter_app) that targets iOS, Android, and web.

## Repository layout

- `agent.py`: the LiveKit Mila voice agent worker
- `token_server.py`: FastAPI token issuer for Flutter clients
- `memory_service.py`, `employee_service.py`, `action_service.py`, `telegram_service.py`: backend business integrations
- `docker-compose.yml`: local PostgreSQL + pgvector container
- `mila_flutter_app/`: Flutter app for iOS, Android, and web that connects through `/token`

## Backend environment variables

Copy `.env.example` to `.env.local` for local development, or set the same variables directly in your deploy platform for production.

Required for `/token`:

- `LIVEKIT_URL`
- `LIVEKIT_API_KEY`
- `LIVEKIT_API_SECRET`

Required for the full Mila agent workflow:

- `DATABASE_URL`
- `GOOGLE_API_KEY`
- `TELEGRAM_BOT_TOKEN`
- `TELEGRAM_STAFF_CHAT_ID`

If you use the bundled local PostgreSQL container from `docker-compose.yml`, the matching local value is:

```text
DATABASE_URL=postgresql://mila:mila_strong_password_change_me@localhost:5432/mila_ai
```

Optional backend settings:

- `MEMORY_USER_ID`
- `MEMORY_COMPANY_ID`
- `MEMORY_EMBEDDING_MODEL`
- `MEMORY_EMBEDDING_DIM`
- `ENABLE_DEBUG_ENV=false`
- `CORS_ALLOW_ORIGINS`
- `CORS_ALLOW_ORIGIN_REGEX`
- `HOST=0.0.0.0`
- `PORT=8000`
- `UVICORN_RELOAD=false`
- `MILA_SERVICE_MODE=web`
- `LIVEKIT_AGENT_COMMAND=start`
- `EMPLOYEES_CSV_PATH`

Do not place any of these secrets in the Flutter app.

## Run the backend

1. Start PostgreSQL with pgvector if you need memory, employee, and action storage:

   ```powershell
   docker compose up -d
   ```

   This initializes every SQL file in [`db/`](./db), including memory, employee, Telegram target, and pending action tables on a fresh database.

2. Create or activate a Python 3.11 or 3.12 virtual environment, then install dependencies:

   ```powershell
   py -3.12 -m venv .venv
   .\.venv\Scripts\Activate.ps1
   pip install -r requirements.txt
   ```

3. Copy `.env.example` to `.env.local` and fill in the real backend secrets.

4. Start the token server:

   ```powershell
   python -m uvicorn token_server:app --host 0.0.0.0 --port 8000 --reload
   ```

5. In a second terminal, start the LiveKit agent worker:

   ```powershell
   python agent.py dev
   ```

For a long-running worker instead of development mode, use:

```powershell
python agent.py start
```

If you want to import employee records from the repository CSV, run:

```powershell
python import_employees.py
```

By default the importer reads [`imports/employees.csv`](./imports/employees.csv). You can override that path with `EMPLOYEES_CSV_PATH`.

### Backend behavior notes

- `POST /token` returns `server_url` and `participant_token` for the Flutter app.
- `GET /health` returns a simple readiness response.
- `GET /debug-env` is hidden unless `ENABLE_DEBUG_ENV=true`.
- If LiveKit environment variables are missing, `/token` returns a clear `500` error with the missing variable names.
- Browser clients are supported through FastAPI CORS middleware.

## GitHub and deployment

The backend is now prepared for GitHub and hosted deployment:

- a root `.gitignore` keeps secrets, local database files, imports, and build outputs out of the repository
- `.dockerignore` keeps deployment images clean
- `Dockerfile` builds a backend image for both the API and the worker
- `service_runner.py` lets the same image run as a web service, worker, database bootstrap job, or employee import job
- `bootstrap_database.py` safely creates the required hosted PostgreSQL schema without dropping existing employee data
- `.github/workflows/backend-verify.yml` runs backend syntax + Docker image checks on GitHub
- `.github/workflows/flutter-web-pages.yml` builds Flutter web on pull requests and deploys to GitHub Pages from `main`
- `render.yaml` provisions web + worker + Postgres on Render from this repository
- `.env.render.example` gives a safe env template for hosted deployment

For the exact deployment workflow, see [`DEPLOYMENT.md`](./DEPLOYMENT.md).

### Fast launch from GitHub

1. Push this repository to GitHub.
2. On Render, create a new **Blueprint** service from the repo (`render.yaml`).
3. Provide required secret values when prompted (`sync: false` variables).
4. In GitHub, enable **Pages** for this repository (GitHub Actions source).
5. Push to `main` to trigger both:
   - backend verification (`Backend Verify`)
   - Flutter web deploy (`Flutter Web (Pages)`)

## Flutter apps

The Flutter client lives in [`mila_flutter_app`](./mila_flutter_app) and uses:

- `livekit_client`
- `http`
- `flutter_secure_storage`
- `permission_handler`
- `provider`

### What the app does

- Stores the backend base URL securely on-device
- Calls `POST {backendBaseUrl}/token`
- Connects to LiveKit with the returned `server_url` and `participant_token`
- Publishes microphone audio
- Plays Mila audio automatically through LiveKit subscriptions
- Supports disconnect, mic mute/unmute, and an optional camera toggle
- Sends a platform source of `web`, `android`, or `ios` to `/token`

## Run the Flutter web app

Browser calls to `/token` need CORS. By default, `token_server.py` allows localhost and `127.0.0.1` origins on any port for local Flutter web development. For production web, set:

```text
CORS_ALLOW_ORIGINS=https://your-web-app-domain
```

### Web development

```bash
cd mila_flutter_app
flutter pub get
flutter run -d chrome
```

Suggested backend URLs inside the app:

- same machine local backend: `http://127.0.0.1:8000`
- production: `https://my-domain.com`

## Run the Flutter Android app

### Android emulator

```bash
cd mila_flutter_app
flutter pub get
flutter run -d android
```

Suggested backend URL inside the app:

- Android emulator to host machine: `http://10.0.2.2:8000`

### Real Android phone

Use a backend URL reachable over Wi-Fi or the internet:

- local network: `http://YOUR_PC_LAN_IP:8000`
- production: `https://my-domain.com`

The debug and profile Android manifests allow cleartext HTTP for local development. Use HTTPS in production.

## Run the Flutter iOS app

You need a Mac with Xcode to run or build the iOS app.

### iOS simulator

1. Open a terminal on a Mac.
2. Change into the Flutter app directory:

   ```bash
   cd mila_flutter_app
   flutter pub get
   ```

3. Launch an iOS simulator from Xcode or the Simulator app.
4. Run the app:

   ```bash
   flutter run -d ios
   ```

5. In the app, open **Settings** and save a reachable backend base URL.

Notes:

- `https://my-domain.com` is the intended production format.
- If the backend is only running locally, the simulator must be able to reach that machine. `localhost` only works when the backend runs on the same Mac as the simulator.
- Camera publishing usually does not work in the iOS simulator, so voice-first testing is the best path there.

### Real iPhone

1. Open `mila_flutter_app/ios/Runner.xcworkspace` in Xcode.
2. Set your Apple Developer team for the `Runner` target.
3. Connect the iPhone and trust the development certificate on the device if prompted.
4. Install dependencies and run:

   ```bash
   cd mila_flutter_app
   flutter pub get
   flutter run -d <your-device-id>
   ```

5. In the app, save a backend URL that the phone can actually reach over Wi-Fi or the internet.

## Build for iOS / Android / web

1. Update the app version in `mila_flutter_app/pubspec.yaml`.
2. Install dependencies:

   ```bash
   cd mila_flutter_app
   flutter pub get
   ```

3. Build the target you need:

   ```bash
   flutter build web
   flutter build apk --debug
   flutter build ipa --release
   ```

For Android release signing and step-by-step APK commands, see [`APK_BUILD_GUIDE.md`](./APK_BUILD_GUIDE.md).

### Android release build

1. Copy `mila_flutter_app/android/key.properties.example` to `mila_flutter_app/android/key.properties`
2. Create a real keystore file such as `mila-upload-keystore.jks`
3. Fill the real keystore values into `key.properties`
4. Build:

   ```bash
   cd mila_flutter_app
   flutter build apk --release
   flutter build appbundle --release
   ```

Before shipping:

- verify the backend URL is configurable inside the app
- verify microphone and camera permissions are correct per platform
- verify the production backend is using HTTPS
- verify production web CORS is locked to the real web app domain
- verify `.env.local` and any real secrets are only present on the backend host

## App configuration inside Flutter

Inside the app:

1. Open **Settings**
2. Enter the backend base URL
3. Tap **Save Backend URL**
4. Return to the home screen and tap **Talk to Mila**

Examples:

- web local: `http://127.0.0.1:8000`
- Android emulator: `http://10.0.2.2:8000`
- Android phone on LAN: `http://YOUR_PC_LAN_IP:8000`
- production: `https://my-domain.com`

The app sends this JSON body to `/token`:

```json
{
  "participant_identity": "ios-user",
  "participant_name": "Beknazar iOS",
  "source": "ios"
}
```

## Development guardrails

- No backend secrets are stored in Flutter.
- The Flutter app does not include `LIVEKIT_API_SECRET`, Telegram tokens, database URLs, or model API keys.
- Existing backend folders like `.venv`, `node_modules`, and `data/postgres` remain outside the Flutter app.
