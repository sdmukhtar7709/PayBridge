# Cash IO (WIP)

Cash IO is an in-progress full-stack project for cash ↔ digital transaction workflows.

This repository currently contains:
- `mobile_app/` — Flutter app (user + agent flows)
- `backend/backend/` — Node.js + TypeScript API (Express + Prisma + PostgreSQL)
- `admin/` — static admin dashboard UI (HTML/CSS/JS)

## Status

🚧 **Work in Progress**

This project is not complete yet. Core modules are being built and integrated.

## Current stack

- Flutter (Dart)
- Node.js + Express + TypeScript
- Prisma ORM
- PostgreSQL (Docker)
- Vitest + Supertest (backend tests)

## Quick start

### 1) Backend API

From project root:

```bash
cd backend/backend
npm install
```

Create `.env` (or copy from `.env.example` if present) and set at minimum:

```env
DATABASE_URL=postgresql://cash_user:cash_password@localhost:5432/cash_db
JWT_SECRET=super-secret-dev
PORT=4000
```

Start PostgreSQL with Docker:

```bash
docker-compose up -d
```

Run migrations and start API:

```bash
npx prisma migrate dev
npm run dev
```

Health check:

```bash
curl http://localhost:4000/health
```

### 2) Mobile app (Flutter)

From project root:

```bash
cd mobile_app
flutter pub get
flutter run
```

### 3) Admin UI

The admin panel is static for now.

Open `admin/index.html` directly in the browser, or use VS Code Live Server.

## Backend scripts

Inside `backend/backend`:

- `npm run dev` — start development server
- `npm run build` — compile TypeScript
- `npm run start` — run compiled app
- `npm test` — run tests
- `npm run check` — type check

## Repository structure

```text
Cash_IO/
├─ admin/
├─ backend/
│  └─ backend/
├─ mobile_app/
└─ README.md
```

## Planned next work

- Complete end-to-end API integration with mobile and admin
- Improve role-based flows (user/agent/admin)
- Harden validation, auth, and error handling
- Add more automated tests and deployment docs

## Note

Some modules/screens are partially implemented and may change as development continues.
