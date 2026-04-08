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
npm install
npx prisma migrate dev
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
