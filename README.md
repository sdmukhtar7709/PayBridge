# PayBridge

## Project overview
PayBridge is an in-progress, full‑stack prototype that explores a *cash–digital payment bridge*: helping users convert between UPI (or other digital transfers) and physical cash through nearby verified agents. The repository currently contains a Flutter mobile application (user and agent flows), a Node.js/Express backend API with a PostgreSQL database via Prisma, and a lightweight web-based admin UI.

This project is being developed as a learning-focused, academic build: the emphasis is on clear architecture, traceable transactions, and practical engineering trade-offs rather than production readiness.

## Problem statement
In many local contexts, people frequently need to move value between digital payment systems (e.g., UPI) and cash. Common ad-hoc approaches (asking friends, visiting informal agents, or using unstructured cash handling) can be slow, inconsistent, and difficult to trust. From a systems perspective, the key challenges are:

- **Discovery**: finding a nearby agent who is available and can handle a requested amount.
- **Trust and verification**: ensuring both parties can confirm the exchange happened correctly.
- **Auditability**: recording transactions so disputes can be handled with evidence.
- **Operational control**: allowing an administrator to approve or restrict agent access.

## Objectives
The current MVP objectives (from the project docs) are:

- Enable users to request **cash-in** (deposit cash) and **cash-out** (receive cash).
- Support **nearby agent discovery** (location-based matching/search).
- Provide **secure verification** (OTP/QR-style confirmation) and durable **transaction logging**.
- Offer **basic admin controls** for approving or banning agents.

## Current features
What is implemented in this repository today (as of January 2026) includes:

- **Backend API (Node.js/Express + TypeScript)**
  - Authentication endpoints for **signup** and **login** (JWT-based).
  - **Health** endpoint with database connectivity check.
  - Transaction and account primitives:
    - Create and list transactions (with basic filtering).
    - Transfer flow between user-owned accounts (atomic update via database transaction).
  - Agent-specific transaction handling:
    - Create agent-handled transactions (cash in/out/transfer) with a **PENDING** status.
    - Approve/reject flow that updates balances atomically when approved.
  - Supporting infrastructure endpoints (present in routes): docs, metrics, versioning, maps proxy, categories, and agent/admin route groups.
  - Input validation patterns using schema validation.
  - Automated tests for selected API behaviours (Vitest).

- **Mobile app (Flutter/Dart)**
  - Auth UI: login and registration screens.
  - User-facing screens for profile/settings and transaction-related flows (including UPI↔cash screens).
  - Agent-facing screens for access/login, home, and registration.

- **Admin UI (HTML/CSS/JS)**
  - A basic admin interface with **demo-only** controls (e.g., approve/reject agent, toggle service status). Integration with backend APIs is marked as TODO.

Notes on scope honesty:
- Some repository docs refer to **React Native** as the mobile client; the current implementation in this workspace is **Flutter**.
- Several front-end/admin actions are currently UI/demo placeholders and may not be fully wired to backend endpoints.

## Tech stack
- **Mobile**: Flutter, Dart
- **Backend**: Node.js, Express, TypeScript
- **Database/ORM**: PostgreSQL, Prisma
- **Validation**: Zod
- **Auth**: JSON Web Tokens (JWT)
- **Testing**: Vitest, Supertest
- **Observability/Docs**: Prometheus client (`prom-client`), Swagger UI
- **Maps/Geo utilities**: Google Maps services client
- **Admin UI**: HTML, CSS, vanilla JavaScript
- **Tooling/Infra (local dev)**: Docker Compose

## Project status
**In Progress.**

The system represents an evolving MVP prototype. Core backend building blocks (auth, database, transaction flows, agent status updates) exist, while broader product concerns—complete UI/API integration, hardened security, full agent verification/KYC processes, production deployment, and comprehensive UX validation—remain ongoing work.

## Learning outcomes
This project is intended to develop practical skills in:

- Designing an MVP from requirements (charter/scope/user stories) and mapping them to implementable modules.
- Implementing and testing REST APIs with role-based access control and input validation.
- Data modelling and transactional integrity (atomic balance updates; state transitions).
- Mobile app development for multi-role flows (user vs agent) and basic settings UX.
- Observability and documentation practices (metrics endpoints, API docs scaffolding).
- Working with real-world trade-offs: incomplete integration, evolving scope, and iterative refactoring.
