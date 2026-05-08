# Deployment Guide

This backend is designed to run as two deployed services that share the same repository and environment:

- `web`: the FastAPI token server
- `worker`: the LiveKit Mila agent worker

Both services also need a PostgreSQL database with the `pgvector` extension enabled.

## 0. Blueprint deploy (Render)

This repository includes a Render Blueprint file at [`render.yaml`](./render.yaml).

Fast path:

1. Push this repo to GitHub.
2. In Render, create a new **Blueprint** from the repository.
3. Render creates:
   - `mila-web` (web service)
   - `mila-worker` (background worker)
   - `mila-postgres` (PostgreSQL)
4. Fill all `sync: false` variables during setup (use [`.env.render.example`](./.env.render.example) as a checklist).

## 1. Prepare the repository for GitHub

The root `.gitignore` now excludes:

- `.env.local` and other local secret files
- `.env.render-*` secret env files
- virtual environments
- `data/` PostgreSQL volumes
- `imports/*.csv` employee data files
- generated Flutter and Android artifacts
- local keystores and backup SQL dumps

GitHub workflows included:

- `.github/workflows/backend-verify.yml`
- `.github/workflows/flutter-web-pages.yml`

Before your first push:

1. Keep `.env.example`
2. Do not commit `.env.local`
3. Do not commit `data/`
4. Do not commit real `imports/*.csv`

If you need an employee import template, use [`imports/employees.sample.csv`](./imports/employees.sample.csv).

## 2. Build the deployment image

From the repository root:

```bash
docker build -t mila-backend .
```

The image starts `service_runner.py`, which supports these modes:

- `MILA_SERVICE_MODE=web`
- `MILA_SERVICE_MODE=worker`
- `MILA_SERVICE_MODE=bootstrap-db`
- `MILA_SERVICE_MODE=import-employees`

## 3. Create the database

Your hosted PostgreSQL database must support:

- `pgcrypto`
- `vector`

Set `DATABASE_URL` in your deploy platform, then run a one-time bootstrap job:

```bash
docker run --rm \
  -e DATABASE_URL=postgresql://... \
  -e MILA_SERVICE_MODE=bootstrap-db \
  mila-backend
```

This applies:

- `db/init.sql`
- `db/employees.sql`
- `db/action_layer.sql`

## 4. Deploy the web service

Set these required environment variables:

- `LIVEKIT_URL`
- `LIVEKIT_API_KEY`
- `LIVEKIT_API_SECRET`
- `DATABASE_URL`
- `GOOGLE_API_KEY`
- `TELEGRAM_BOT_TOKEN`
- `TELEGRAM_STAFF_CHAT_ID`

Recommended optional variables:

- `CORS_ALLOW_ORIGINS=https://your-frontend-domain`
- `ENABLE_DEBUG_ENV=false`
- `PORT` provided by your host

Run the web service with:

```bash
docker run --rm -p 8000:8000 \
  -e MILA_SERVICE_MODE=web \
  --env-file .env.local \
  mila-backend
```

Health endpoint:

```text
GET /health
```

## 5. Deploy the worker service

Use the same repository, image, and environment variables, but set:

```text
MILA_SERVICE_MODE=worker
LIVEKIT_AGENT_COMMAND=start
```

Run:

```bash
docker run --rm \
  -e MILA_SERVICE_MODE=worker \
  --env-file .env.local \
  mila-backend
```

## 6. Optional employee import job

To import employees from a CSV in a one-off job:

```bash
docker run --rm \
  -e MILA_SERVICE_MODE=import-employees \
  -e EMPLOYEES_CSV_PATH=/app/imports/employees.csv \
  --env-file .env.local \
  mila-backend
```

## 7. Environment file behavior

In deployed environments, platform variables are enough.

Local files are optional:

- `.env`
- `.env.local`
- or a custom file path via `MILA_ENV_FILE`

Environment variables provided by the platform take priority over values loaded from files.
