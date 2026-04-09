# Cash IO

Cash IO is a full-stack project for cash and digital transaction workflows.

This repository includes:
- `backend/backend` - Node.js + TypeScript API (Express + Prisma + PostgreSQL)
- `mobile_app` - Flutter mobile app
- `admin` - Admin web UI (HTML/CSS/JS), served by backend

## Project status

Work in progress. Core flows are implemented and can run locally for development.

## Tech stack

- Backend: Node.js, TypeScript, Express, Prisma
- Database: PostgreSQL (Docker)
- Mobile: Flutter (Dart)
- Testing: Vitest + Supertest (backend)

## Super Easy Run (Copy-Paste)

Follow any one option below.

### Option A: Docker Desktop installed (local DB)

1. Open terminal in project root `Cash_IO`.
2. Run:

```powershell
cd backend/backend
npm run setup
npm run dev
```

3. Open health URL:

- http://localhost:4000/health

### Option B: No Docker Desktop (hosted DB)

1. Open terminal in project root `Cash_IO`.
2. Run:

```powershell
cd backend/backend
$env:SETUP_DATABASE_URL="postgresql://USER:PASSWORD@HOST:5432/DB_NAME?sslmode=require"
npm run setup:hosted
npm run dev
```

3. Open health URL:

- http://localhost:4000/health

Important:

- If same `DATABASE_URL` is used by multiple developers, everyone sees same existing DB data.
- If local Docker DB is used, that data is separate per machine.

## Run in 5 simple steps (recommended)

Use this if you want the fastest path to run the project locally.

1. Install prerequisites
2. Start PostgreSQL with Docker
3. Configure backend `.env`
4. Run backend
5. Open admin UI and/or run mobile app

Details are below.

## 1) Prerequisites

Install these tools first:
- Node.js 20+
- npm 10+
- Docker Desktop
- Flutter SDK (for mobile only)
- Git

Check versions:

```bash
node -v
npm -v
docker --version
flutter --version
```

## 2) Start database (PostgreSQL)

From repository root:

```bash
cd backend/backend
docker-compose up -d
```

This starts Postgres with:
- host: `localhost`
- port: `5432`
- user: `cash_user`
- password: `cash_password`
- database: `cash_db`

## 3) Configure backend environment

In `backend/backend`, create a file named `.env` with this content:

```env
DATABASE_URL=postgresql://cash_user:cash_password@localhost:5432/cash_db
JWT_SECRET=dev-secret-change-me
PORT=4000
NODE_ENV=development
ADMIN_REGISTRATION_CODE=dev-admin-register-code
ALLOWED_ORIGINS=
```

Optional variables (only if needed):

```env
GOOGLE_MAPS_API_KEY=
LOG_LEVEL=info
```

## 4) Run backend API

From `backend/backend`:

```bash
npm run setup
npm run dev
```

What `npm run setup` does:
- creates `.env` from `.env.example` (if missing)
- installs dependencies
- starts PostgreSQL (Docker local mode)
- runs Prisma generate + migrations + seed

Alternative (manual steps):

```bash
npm install
npx prisma migrate dev
npm run dev
```

Hosted DB (no Docker):

```powershell
cd backend/backend
$env:SETUP_DATABASE_URL="postgresql://USER:PASSWORD@HOST:5432/DB_NAME?sslmode=require"
npm run setup:hosted
npm run dev
```

Backend runs at:
- `http://localhost:4000`

Quick checks:
- Health: `http://localhost:4000/health`
- API docs UI: `http://localhost:4000/docs`
- OpenAPI JSON: `http://localhost:4000/docs/openapi.json`

## 5) Run frontend parts

### Admin UI (easiest)

With backend running, open:
- `http://localhost:4000/admin-ui/AuthScreen/index.html`

### Mobile app (Flutter)

From repository root:

```bash
cd mobile_app
flutter pub get
flutter run
```

## All useful commands

### Backend (`backend/backend`)

```bash
npm run dev         # start dev server
npm run build       # compile TypeScript
npm run start       # run compiled server
npm run check       # TypeScript type-check
npm test            # run tests
npm run test:watch  # watch tests
npm run studio      # open Prisma Studio
```

### Mobile (`mobile_app`)

```bash
flutter pub get
flutter run
flutter test
```

## Windows quick commands (PowerShell)

If you are on Windows PowerShell, this exact sequence works:

```powershell
cd backend/backend
docker-compose up -d
npm install
npx prisma migrate dev
npm run dev
```

In a second terminal:

```powershell
cd mobile_app
flutter pub get
flutter run
```

## Repository structure

```text
Cash_IO/
|- admin/
|- backend/
|  |- backend/
|- mobile_app/
|- README.md
```

## Troubleshooting

### Port 4000 already in use

Change `PORT` in `.env`, then restart backend.

### Database connection error

Check Docker is running and container is up:

```bash
docker ps
```

Then verify `DATABASE_URL` in `.env`.

### Prisma migration issues

Run from `backend/backend` only:

```bash
npx prisma migrate dev
```

### Flutter device not found

Run:

```bash
flutter doctor
flutter devices
```

## Notes

- Some modules are still under active development.
- API and UI details may evolve as features are completed.

## No Docker Setup (Step by Step, After Download)

Use this flow if Docker Desktop is not installed on your PC.

### What you need

- Node.js 20+
- npm 10+
- Git
- One hosted PostgreSQL database URL (Neon/Supabase/Railway/Render)

### 1) Download or clone project

Option A (Git clone):

```bash
git clone <repo-url>
cd Cash_IO
```

Option B (ZIP download):

1. Download ZIP from GitHub.
2. Extract the ZIP.
3. Open terminal in extracted `Cash_IO` folder.

### 2) Go to backend folder

```powershell
cd backend/backend
```

### 3) Set hosted database URL (PowerShell)

```powershell
$env:SETUP_DATABASE_URL="postgresql://USER:PASSWORD@HOST:5432/DB_NAME?sslmode=require"
```

Replace `USER`, `PASSWORD`, `HOST`, and `DB_NAME` with your real database values.

### 4) Run automated setup (no Docker)

```powershell
npm run setup:hosted
```

This command automatically:

- creates `.env`
- installs dependencies
- runs Prisma generate
- runs migrations
- seeds demo data

### 5) Start backend

```powershell
npm run dev
```

Backend URL:

- http://localhost:4000

Health check:

- http://localhost:4000/health

### 6) Open Admin UI

- http://localhost:4000/admin-ui/AuthScreen/index.html

### Common issue

If setup says database connection failed, verify that:

1. Hosted DB URL is correct.
2. SSL is enabled (usually `?sslmode=require`).
3. Database user has permission to create/read tables.
