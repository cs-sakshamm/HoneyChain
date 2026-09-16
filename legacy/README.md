# HoneyChain — Legacy / Archived Code

This directory contains the **deprecated Express + Prisma backend** that used to
live in `backend/src/`, `backend/prisma/`, and `backend/dist/`.

## Why it was archived

The project originally shipped with **two competing backends**:

| | Express/TypeScript (archived here) | FastAPI (active) |
|---|---|---|
| Entry point | `express_backend/index.ts` | `backend/main.py` |
| Database | Prisma → SQLite (`dev.db`) | SQLAlchemy → PostgreSQL |
| Schema style | camelCase | snake_case |
| State sharing | none with FastAPI | authoritative |

The Flutter mobile app talks to **FastAPI on port 8000** only. The Express
service duplicated auth/verification/workflow logic against a separate database,
causing state divergence. All of its useful logic (multi-role account discovery,
`/api/auth/switch-role`, verification flows, profile gates) has been natively
re-implemented in `backend/main.py`.

## If you ever need it

```bash
cd legacy/express_backend
npm install          # deps are in ../express_backend_package.json
npx prisma generate  # schema in ../express_backend_prisma/schema.prisma
npx tsx index.ts
```

Nothing in the active system imports from this directory. It is kept for
historical reference only and is excluded from Docker builds.
