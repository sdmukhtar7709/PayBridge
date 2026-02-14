# Cash Platform Backend

## Prerequisites
- Node.js (LTS)
- Docker (for Postgres) or a local Postgres instance

## Environment
Copy `.env.example` to `.env` (if present) or ensure these are set:
```
DATABASE_URL="postgresql://postgres:postgres@localhost:5432/cash_platform?schema=public"
JWT_SECRET="please-change-me-to-a-long-random-string"
PORT=3000
```

## Database
Start Postgres (compose):
```bash
docker-compose up -d
```

Run migrations:
```bash
npm install
npx prisma migrate dev --name init
```

Seed demo user:
```bash
npx prisma db seed
# demo@example.com / password123
```

## Run the API
```bash
npm run dev
```

## Health & Auth
- Health: `GET /health` -> `{ ok: true, db: "up" }`
- Signup: `POST /auth/signup` with `{ "name": "...", "email": "...", "password": "..." }`
- Login: `POST /auth/login` with `{ "email": "...", "password": "..." }`
