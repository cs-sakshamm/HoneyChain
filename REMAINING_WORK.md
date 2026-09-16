# HoneyChain — REMAINING WORK LIST

Built from the live 2026-09-16 audit (see PROJECT_CURRENT_STATUS.md for evidence). Not copied from any prior checklist.

Priority: P0 blocking foundation · P1 core workflow/security · P2 integration · P3 testing/cleanup · P4 deployment · P5 docs

## Task Tracker

| ID | Priority | Task | Status | Dependency | Verification |
|----|----------|------|--------|------------|--------------|
| HC-001 | P0 | Remove unauthenticated duplicate `PATCH /api/requests/{id}/reject` + `/status` handlers (anonymous tampering) | 🟢 FIXED & VERIFIED | None | 401 without token; guarded behavior with token; full pytest green |
| HC-002 | P1 | Set a real `JWT_SECRET_KEY` (fallback constant is public) | 🟢 FIXED & VERIFIED | None | `.env` key set; tokens still verify after restart |

### HC-001 evidence record

```
Task performed: Removed the first (dependency-less) duplicate declarations of
  PATCH /api/requests/{request_id}/reject and PATCH /api/requests/{request_id}/status
  in backend/main.py; preserved their unique behaviors (packaging-batch reject branch,
  PROCESSING stage mapping) by porting them into the surviving authenticated handlers.
Expected: anonymous PATCH -> 401; authed PATCH -> 200; unknown status -> 422;
  DB untouched by anonymous attempts; full suite green.
Actual (executed 2026-09-16):
  [PASS] reject without token            expected=401 actual=401
  [PASS] status without token            expected=401 actual=401
  [PASS] db unchanged after anon attempts expected=PENDING actual=PENDING
  [PASS] status with token               expected=200 actual=200
  [PASS] db updated by authed call       expected=PROCESSING actual=PROCESSING
  [PASS] unknown status rejected         expected=422 actual=422
  pytest backend/tests/  ->  5 passed in 80.57s
Result: 🟢 FIXED & VERIFIED
```

### HC-002 evidence record

```
Task performed: Generated a cryptographically random 256-bit secret and wrote
  JWT_SECRET_KEY to backend/.env (gitignored — never committed). Value never
  echoed to terminal.
Expected: app-issued tokens authenticate (200); token forged with the old
  public fallback key rejected (401); garbage token rejected (401); tokens
  still verify after a simulated restart (fresh process re-reads .env).
Actual (executed 2026-09-16):
  [PASS] app-issued token authenticates          200 ✓
  [PASS] fallback-key forged token REJECTED      401 ✓
  [PASS] garbage token rejected                  401 ✓
  [PASS] token verifies after simulated restart  key_prefix=9772, sub match ✓
  pytest backend/tests/  ->  5 passed in 56.32s
Result: 🟢 FIXED & VERIFIED
Note: all previously issued mobile sessions are invalid; users re-login once.
```

---
| HC-003 | P1 | Commit the audited uncommitted work (auth guards, tests, token store) as a clean checkpoint | 🔵 NEEDS VERIFICATION | HC-001 | `git diff -- ai_ml/` empty; suite green at commit point |
| HC-004 | P1 | Rotate Supabase password; document secret handling (plaintext in local `.env`) | 🔵 NEEDS VERIFICATION | None | User action: rotate in Supabase dashboard; `.env` updated |
| HC-005 | P1 | `/api/auth/google`: reject bare-email auth when no `idToken` in production mode | 🟡 PARTIAL | None | 400 without idToken (prod), sandbox still allowed for dev |
| HC-006 | P2 | Live MQTT round-trip test: publish raw telemetry → AI/ML → processed → backend → DB | 🔵 NEEDS VERIFICATION | None (broker already running) | `hive_telemetry` + `hive_ai_analysis` rows from a live publish |
| HC-007 | P2 | ESP32 firmware: configurable broker host/creds instead of `broker.honeychain.io` placeholders | ⚪ NOT STARTED | None | Compiles; publishes to local broker |
| HC-008 | P2 | Blockchain on-chain proof: start Hardhat node, deploy, verify tx hash round-trip end-to-end | 🔵 NEEDS VERIFICATION | None (node present) | `blockchain_records.status=CONFIRMED` + real `tx_hash` read back |
| HC-009 | P2 | Flutter verification: `flutter analyze` + run app against backend | 🔵 NEEDS VERIFICATION | None | Zero analyzer errors; login works from app |
| HC-010 | P4 | Production deploy config: `PUBLIC_APP_URL`, CORS origins, JWT secret, seed flag off | ⚪ NOT STARTED | HC-002 | QR encodes public URL; verify page reachable from phone |
| HC-011 | P3 | Stale backend README (Node/prisma section) + duplicate section banner in main.py | ⚪ NOT STARTED | None | Docs match reality |
| HC-012 | P2 | Android package id `com.example.mobile_app` → production id | ⚪ NOT STARTED | None | Release build with final applicationId |

## Dependency Order

```
HC-001 (auth hole)  ──►  HC-003 (commit checkpoint)
HC-002 (JWT secret) ──►  HC-010 (deploy)
HC-006 (MQTT live)  ──►  HC-008 (needs broker infra too)
HC-009 (flutter)    ──►  HC-012 (release)
```

Core workflow (registration→login→profile→hive→collection→lab→packaging→QR→verify) is ALREADY
VERIFIED GREEN by the executed pytest suites — remaining tasks close security holes and prove the
live/production paths (MQTT sockets, on-chain tx, Flutter runtime).

## Completed during prior sessions (verified this audit, not re-listed as tasks)

- Auth guards on profile/hive/workflow creation (403 PROFILE_INCOMPLETE / FORBIDDEN) ✅ tested
- State-machine hardening on PUT /api/requests (terminal states, unknown statuses) ✅ tested
- SEED_DEMO_DATA env-gated seeding (no silent demo data) ✅ verified in lifespan code
- Lab report real-threshold certification (moisture/HMF/diastase) ✅ tested
- E2E + scenario tests green against real Postgres ✅ executed
- ai_ml/ UNTOUCHED ✅ `git diff ai_ml/` empty
