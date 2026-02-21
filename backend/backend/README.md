# Cash Platform – Backend

TypeScript/Node.js backend for the Cash Platform project.

## Tech stack

- Node.js (>= 20)
- TypeScript
- Express
- Prisma
- Pino
- Vitest

## How to run after clone (step by step)

From a terminal:

1. **Clone and enter the backend folder**

   ```bash
   git clone <your-repo-url>
   cd cash-platform/backend
   ```

2. **Install dependencies**

   ```bash
   npm install
   ```

3. **Create `.env` from the example**

   ```bash
   cp .env.example .env   # on Windows PowerShell you can use: copy .env.example .env
   ```

   Then open `.env` and adjust values if needed (e.g. `JWT_SECRET`, `PORT`, `DATABASE_URL`).

4. **Start Postgres via Docker**
   Make sure Docker Desktop is running, then:

   ```bash
   docker-compose up -d
   ```

   This starts a Postgres 16 container with:

   - user: `cash_user`
   - password: `cash_password`
   - db name: `cash_db`
     which matches the default `DATABASE_URL` in `.env.example`.

5. **Run Prisma migrations (create tables)**

   ```bash
   npx prisma migrate dev
   ```

   This reads `prisma/schema.prisma` and applies migrations to the `cash_db` database.

6. **(Optional) Seed demo data**
   If you add a `prisma/seed.ts` script (see `generator client` in `schema.prisma`), run:

   ```bash
   npx prisma db seed
   ```

   so tests like `auth.login.success.test.ts` can log in with a demo user.

7. **Start the dev server**

   ```bash
   npm run dev
   ```

   The API should now be listening at:

   - http://localhost:4000

8. **Quick checks**

   - Health:
     ```bash
     curl http://localhost:4000/health
     ```
     Expected: `{"ok":true,"db":"up"}` (or similar).
   - Signup:
     ```bash
     curl -X POST http://localhost:4000/auth/signup \
       -H "Content-Type: application/json" \
       -d '{"name":"Demo","email":"demo@example.com","password":"password123"}'
     ```
   - Login:
     ```bash
     curl -X POST http://localhost:4000/auth/login \
       -H "Content-Type: application/json" \
       -d '{"email":"demo@example.com","password":"password123"}'
     ```

9. **Run tests**
   ```bash
   npm test
   # or
   npx vitest
   ```
   If you don’t have the DB running you can skip DB tests by setting in `.env`:
   ```env
   SKIP_DB_TESTS=1
   ```

## Getting started (short version)

From this `backend` directory:

```bash
npm install
cp .env.example .env
docker-compose up -d
npx prisma migrate dev
npm run dev
```

## Security / vulnerabilities

After installing dependencies you may see output like:

```text
4 vulnerabilities (3 high, 1 critical)
To address all issues, run:
  npm audit fix
```

Recommended:

1. Try to auto-fix:
   ```bash
   npm audit fix
   ```
2. If issues remain, review `npm audit` output and decide case‑by‑case
   (sometimes the remaining advisories are in transitive devDependencies only).

## Project structure

- `src/` – application code
- `prisma/` – Prisma schema and migrations
- `node_modules/` – installed dependencies (ignored in git)
- `package.json` / `package-lock.json` – npm metadata/lockfile

## Database (Postgres via Docker)

From this `backend` directory (with Docker Desktop running):

```bash
docker-compose up -d
```

Then apply Prisma migrations:

```bash
npx prisma migrate dev
```

Make sure `.env` has:

```env
DATABASE_URL=postgresql://cash_user:cash_password@localhost:5432/cash_db
JWT_SECRET=super-secret-dev
PORT=4000
```

## Health & Auth

- Health: `GET /health` -> `{ ok: true, db: "up" }`
- Signup: `POST /auth/signup` with `{ "name": "...", "email": "...", "password": "..." }`
- Login: `POST /auth/login` with `{ "email": "...", "password": "..." }`
