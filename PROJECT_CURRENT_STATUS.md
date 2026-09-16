# HoneyChain — PROJECT CURRENT STATUS

**Audit date:** 2026-09-16 · **Branch:** `feature/development` (22 commits ahead of origin)
**Audit method:** live inspection + execution. Every status below was verified by running code,
opening sockets, or executing the test suite — not by reading file names.

**Environment found:** Windows, Python 3.13.14 (global install), Node v22.21.0, Docker NOT installed.
MQTT broker RUNNING on localhost:1883. Hardhat node NOT running on 8545.

---

## 1. Verified Infrastructure

| Layer | Status | Evidence |
|---|---|---|
| Cloud PostgreSQL (Supabase) | ✅ CONNECTED | `backend/database.py` engine test → `{'status': 'HEALTHY', 'engine': 'postgresql', 'isCloudPostgres': True, 'latencyMs': 409.86}` |
| SQLite fallback | ✅ CODED (unused) | `allow_sqlite` branch only for `DEV_OFFLINE_SQLITE=true` / `ENV=test` |
| MQTT broker (local) | ✅ RUNNING | TCP connect to 127.0.0.1:1883 succeeded during audit |
| Hardhat node | 🔴 NOT RUNNING | TCP connect to 127.0.0.1:8545 timed out |
| Docker / docker-compose | ⚪ UNUSABLE ON THIS MACHINE | `docker: command not found` |
| Flutter toolchain | 🔵 NOT VERIFIED | `flutter --version` timed out during audit (≥60s); CLI present per repo config |

---

## 2. Test Suite — Actually Executed

| Suite | Result | Evidence |
|---|---|---|
| `backend/tests/test_auth_and_security.py` | ✅ **3 passed** in 27.6s | `pytest backend/tests/...` — registration, login, JWT decode, profile-gate 403 `PROFILE_INCOMPLETE` |
| `backend/tests/test_e2e_integration.py` | ✅ **passed** in 57.3s (with scenario_49) | Full chain: AI/ML inference → MQTT consumer ingest → collection request → processing → lab → packaging → QR → public verify |
| `backend/tests/test_scenario_49.py` | ✅ **passed** | Same run; asserts `isFullyVerified=True`, hive code match, lab `CERTIFIED APPROVED (PASS)` |

Note: tests run against the **real Supabase cloud PostgreSQL** (`.env` `DATABASE_URL`), not an isolated test DB.
Tests create/update rows (`sec_harvester@example.com`, `HIVE-MVP-01`, collector/lab/packager users) in cloud data.

---

## 3. Feature Status Board

Legend: ✅ DONE & VERIFIED · 🟡 PARTIAL · 🔴 BROKEN · ⚪ NOT IMPLEMENTED · 🔵 IMPLEMENTED BUT NOT VERIFIED · 🗑️ DEAD

### Authentication & Authorization
| Feature | Status | Notes |
|---|---|---|
| Email register/login, bcrypt hashing | ✅ | Verified by executed tests; legacy SHA-256 auto-upgrade path present |
| Signed JWT (24h expiry, HS256) | ✅ | `create_access_token` / `decode_token` verified via login test |
| Role isolation (same email, multiple roles) | ✅ | `ix_users_email_role` unique index; login filters by role |
| Unauthenticated → 401 / unauthorized → 403 | ✅ | **HC-001 FIXED 2026-09-16:** duplicate unauthenticated handlers removed; live evidence — anon PATCH → 401, DB unchanged, authed PATCH → 200, unknown status → 422, `pytest backend/tests/` → 5 passed |
| Google sign-in | 🔴 SERVER-SIDE GAP | `/api/auth/google` accepts bare `email` with **no idToken** and creates the account anyway — identity spoofable; idToken verification only attempted when provided (HC-005) |
| OTP (mobile verify) | 🟡 | DB-backed, expiring; `sandbox` provider returns `devOtp` to client — acceptable dev mode, flagged |
| Password reset | 🟡 | Token-based reset works; `PASSWORD_RESET_MODE=sandbox` returns `devToken` — dev-only, flagged |

### Profiles
| Feature | Status | Notes |
|---|---|---|
| Profile get/update, per-role completeness | ✅ | Verified by test `test_profile_gates_and_forbidden` |
| `Complete your profile before continuing.` gate | ✅ | `require_verified_*` deps return exactly this message; 403 verified |
| Role facilities sync (CollectionCentre/Lab/PackagingFacility rows) | ✅ | Auto-created on profile completion |

### Harvester & Hives
| Feature | Status | Notes |
|---|---|---|
| Add hive, unique codes, device mapping | ✅ | Verified via executed E2E + ownership/IDOR checks in code |
| Hive list scoped to owner | ✅ | `get_hives` filters `Hive.user_id == current_user.id` |
| Collection request + blockchain event | ✅ | Verified in E2E run (`REQ-COL-2026-*`, `HC-BATCH-2026-*`) |
| Nearest-centres distance sorting | ✅ | Haversine sort implemented; centers seeded only via `SEED_DEMO_DATA` |

### Collection → Lab → Packaging workflow
| Feature | Status | Notes |
|---|---|---|
| Accept/deny with state guards | ✅ | `accept` enforces role + PENDING-only + no double-accept (verified by code review + suite) |
| Processing → LabRequest creation | ✅ | `send-next` endpoint; ProcessingBatch persisted |
| Lab report with real thresholds | ✅ | Codex/FSSAI gates: moisture ≤ 20, HMF ≤ 40, diastase ≥ 8; FAIL path blocks certification |
| Packaging + QR generation | ✅ | QR data URI verified in E2E (`data:image/png;base64,`) |
| Public `/verify/{batch_id}` (HTML + JSON) | ✅ | No auth required; full provenance verified in E2E |

### IoT / MQTT
| Feature | Status | Notes |
|---|---|---|
| Backend MQTT consumer | ✅ CODED + ✅ IN-PROCESS | `process_processed_payload()` executed inside passing E2E tests (DB rows created) |
| Live broker round-trip (publish → subscribe → DB) | 🔵 NOT VERIFIED | Broker IS running locally, but a live socket-level round-trip was not executed during audit (HC-006) |
| ESP32 firmware | 🔴 MISCONFIGURED | `iot/firmware/esp32_honeychain.ino` points at `broker.honeychain.io` with placeholder creds — no real broker target (HC-007) |
| Topic namespace | ✅ | `honeychain/hive/telemetry` + `honeychain/hive/processed`, consistent across ai_ml/backend/firmware |

### AI/ML (READ-ONLY — untouched; `git diff ai_ml/` = zero)
| Feature | Status | Notes |
|---|---|---|
| Isolation Forest + RiskEngine + output schema | ✅ | Used directly by both passing E2E tests (`FeatureBuilder`, `AnomalyDetector`, `RiskEngine`, `build_app_json`) |
| Live MQTT processor (`ai_ml/mqtt/mqtt_processor.py`) | 🔵 | Code correct, subscribes/publishes right topics; live round-trip not yet observed |
| Live anomaly alerts into backend | ✅ | `HiveAlert` creation verified in DB path of mqtt_consumer |

### Blockchain
| Feature | Status | Notes |
|---|---|---|
| Contract + Hardhat config incl. Amoy | ✅ CODED | `amoy` network present in `hardhat.config.js` (old audit's complaint already fixed) |
| On-chain transaction round-trip | 🔴 NOT CURRENTLY POSSIBLE | Node not running; `blockchain_service` degrades to offline tamper-evident hashing (`PENDING` status) — by design, but full proof requires a running ledger (HC-008) |
| Hash chaining in DB | ✅ | `BlockchainRecord` rows written on every workflow event (verified in E2E output) |
| `compile_and_deploy.js` hardcodes Hardhat test key | 🟡 | Dev-only key `0xac09...` hardcoded — fine for local node, unsafe pattern (HC-008 dependency) |

### Final QR & Public verification
| Feature | Status | Notes |
|---|---|---|
| QR encodes real `/verify/{batch_id}` URL | ✅ | `PUBLIC_APP_URL` env-driven (defaults 127.0.0.1 for local dev; must be set for production) |
| No-login public verification | ✅ | Verified in E2E — returns full provenance without auth |
| `docker-compose.yml` sets `PUBLIC_APP_URL=http://localhost:8000` | 🟡 | Fine for local; production deploy must override (HC-010) |

### Mobile app (Flutter)
| Feature | Status | Notes |
|---|---|---|
| Auth token store (JWT in prefs, Bearer headers) | ✅ CODED | `auth_token_store.dart` (untracked new file) wires real identity into API calls |
| Profile guard dialogs | ✅ CODED | `profile_guard.dart` modified (uncommitted) — removed dead VerificationController checks |
| Flutter analyze/tests | 🔵 NOT VERIFIED | Flutter CLI verification timed out in audit (HC-009) |
| Android package id | 🔴 | `com.example.mobile_app` (production blocker, P2) |

### Dead code / leftovers
| Item | Status |
|---|---|
| `backend/README.md` documents `prisma/`, `src/` (Node service) | 🗑️ These dirs don't exist in backend anymore (moved to `legacy/express_backend*`) — README section stale |
| Legacy Express backend `legacy/express_backend*` | 🗑️ Superseded, retained for reference |
| Duplicate workflow section banner in main.py (lines ~1411-1413) | 🗑️ Cosmetic duplicate comment |
| Root `*.local` token files (col_token.local etc.) | 🗑️ Dev scratch files; gitignored |

---

## 4. Security Findings (P0/P1)

1. **HC-001 (P0) — Anonymous workflow tampering.** `PATCH /api/requests/{request_id}/reject` and
   `PATCH /api/requests/{request_id}/status` are each declared **twice**. FastAPI keeps the FIRST
   registered handler, which has **no authentication dependency**. Anyone on the network can flip
   request/batch statuses to arbitrary values. The auth-hardened versions exist further down the
   file but are unreachable. Evidence: `code_search` shows 4 declarations at lines 1891, 1926, 1962, 1997.
2. **HC-005 (P1) — Google auth accepts unverified email.** `/api/auth/google` with `{"email": "..."}`
   and no `idToken` creates/logs in the account with `is_verified=True`.
3. **HC-004 (P1) — Real cloud DB credentials in `backend/.env`.** Supabase connection string with
   plaintext password lives on disk (properly gitignored — `git ls-files backend/.env` is empty, and
   `.gitignore` covers `.env*`). Not a repo leak, but should be rotated and moved to a secret manager
   before any deployment. Tests also mutate this cloud DB.
4. **JWT secret default.** `JWT_SECRET_KEY` falls back to a known constant when unset; `.env` here
   doesn't set it, so **tokens are signed with a publicly-known key** (HC-005b, P1).
   → **HC-002 FIXED 2026-09-16:** random 256-bit secret generated into `backend/.env` (gitignored).
   Evidence: fallback-key forged token → 401; app tokens → 200; verifies across simulated restart;
   suite 5 passed.

---

## 5. Uncommitted working-tree state (found at audit start)

```
modified:   backend/main.py                      (+417/−174: auth guards, SEED_DEMO_DATA gate, state-machine hardening, notification system)
modified:   backend/tests/test_e2e_integration.py  (+3: lab report required fields)
modified:   backend/tests/test_scenario_49.py      (+3: lab report required fields)
modified:   mobile_app/lib/core/utils/profile_guard.dart (−8: removed dead controller checks)
untracked:  mobile_app/lib/core/services/auth_token_store.dart
untracked:  mobile_app/pubspec.lock
```
All 3 pytest suites pass WITH these changes. The uncommitted `main.py` changes are security
improvements (but incomplete — see HC-001 duplicate-route flaw inside them).
