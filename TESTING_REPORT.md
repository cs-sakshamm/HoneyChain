# HoneyChain Software Testing Report

## 1. Testing Date

September 16, 2026 — single-session audit. All results below were executed live against a locally running stack (FastAPI on 127.0.0.1:8000, PostgreSQL, Mosquitto :1883).

## 2. Project Structure Tested

| Folder | Technology | Role |
|---|---|---|
| `backend/` | Python 3.13, FastAPI 0.141.1, SQLAlchemy 2.0.52, Alembic, Web3.py, paho-mqtt | Core REST/WS API, MQTT consumer, blockchain writer, QR service |
| `mobile_app/` | Flutter 3.47.2 / Dart, provider state management | 4-role app (harvester, collection, lab, packaging), 87 Dart files |
| `blockchain/` | Solidity 0.8.20, Hardhat 3.16.0, ethers v6 | `HoneyChainProvenance.sol` provenance ledger |
| `ai_ml/` | Python, scikit-learn (Isolation Forest), paho-mqtt | Hive telemetry anomaly detection — **INSPECTED ONLY, NOT MODIFIED** |
| `iot/firmware/` | C++ (Arduino/ESP32) | Sensor firmware (not executable in this environment) |
| `mosquitto/` | Mosquitto 2 config | MQTT broker (auth required) |
| `legacy/` | Express/Prisma (archived) | Deprecated duplicate backend, excluded from runtime |

Data flow verified: ESP32 → MQTT `honeychain/hive/telemetry` → ai_ml → MQTT `honeychain/hive/processed` → FastAPI consumer → PostgreSQL → REST/WebSocket → Flutter → public `/verify/{batch_id}`.

## 3. Environment

- Flutter 3.47.2 (stable), Dart SDK bundled
- Python 3.13.14, FastAPI 0.141.1, SQLAlchemy 2.0.52
- Node v22.21.0, Hardhat 3.16.0
- PostgreSQL: **CONNECTED** (local server, engine reported `postgresql` by `/api/health`)
- Supabase: **NOT CONFIGURED** (no `SUPABASE_URL`/`SUPABASE_KEY` present; plain PostgreSQL is used)
- MQTT broker: connected and functional
- No secrets are reproduced in this report.

## 4. Overall Test Summary

```
Total Tests: 74
PASS: 52
FAIL: 9
BLOCKED: 8
NOT TESTED: 5
```

No percentage is computed. Every PASS below has recorded evidence; FAILs include proof.

## 5. Backend Tests

| Test | Expected | Actual | Status | Evidence |
|---|---|---|---|---|
| Pytest suite (5 tests) | all pass | 5 passed in 58s | PASS | `test_password_hashing`, `test_auth_registration_and_login`, `test_profile_gates_and_forbidden`, `test_e2e_integration`, `test_section_49_scenario` |
| App startup | no exceptions | startup clean, MQTT consumer connected | PASS | `/tmp/hc_backend2.log` |
| Route registration | all routes load | 62 route decorators active | PASS | code scan + live calls |
| `/api/health` | 200 healthy | 200, db HEALTHY | PASS | curl output |
| Malformed JSON handling | 422 | 422 with `json_invalid` | PASS | register `{broken` |
| Missing required field | 422 | 422 with field locator | PASS | register without `name` |
| Unknown route | 404 | 404 | PASS | — |
| `python main.py` direct run | server starts | **exits silently (no `__main__` block)** | FAIL | observed; must use `uvicorn main:app` |
| Hot-restart resilience | server recovers | recovered, DB intact | PASS | restart cycle test |

## 6. API Tests

| Endpoint | Method | Expected | Actual | Status |
|---|---|---|---|---|
| `/api/auth/register` | POST | 200 valid | 200 + JWT + user | PASS |
| `/api/auth/register` duplicate | POST | 409 | 409 `ROLE_ACCOUNT_EXISTS` | PASS |
| `/api/auth/login` (`emailOrPhone`) | POST | 200 | 200 + JWT | PASS |
| `/api/auth/login` wrong password | POST | 401 | 401 `INVALID_PASSWORD` | PASS |
| `/api/auth/login` unknown user | POST | 401 | 401 `USER_NOT_FOUND` | PASS |
| `/api/profile` valid JWT | GET | 200 own profile | 200 `Audit Harvester` | PASS |
| `/api/profile` forged JWT | GET | 401 | **200 + another user's profile** | FAIL |
| `/api/profile` no auth | GET | 401 | **200 + first DB user** | FAIL |
| `/api/hives` (list) | GET | scoped to caller | **returns all users' hives without auth** | FAIL |
| `/api/hives` create | POST | 200 | 200, unique `HIVE-0A426C` | PASS |
| `/api/hives/{id}` PUT by non-owner | PUT | 403 | 403 `FORBIDDEN` | PASS |
| `/api/hives/{id}` DELETE by non-owner | DELETE | 403 | 403 `FORBIDDEN` | PASS |
| `/api/hives` as LAB role | POST | 403 | 403 `Only Harvester accounts…` | PASS |
| `/api/centers/nearest` | GET | 200 | 200, 3 centres | PASS |
| `/api/telemetry/ingest` valid | POST | 200 | 200, telemetryId | PASS |
| `/api/telemetry/ingest` unknown hive | POST | 404 | 404 `HIVE_NOT_FOUND` | PASS |
| `/api/telemetry/ingest` missing hiveId | POST | 404 | 404 | PASS |
| `/api/requests` create | POST | 200 | 200, batch + blockchain hash | PASS |
| `/api/requests` list | GET | 200 (auth recommended) | 200 **with no auth, full chain data** | FAIL |
| `/api/requests/{id}/accept` | PATCH | 200 | 200, batch → COLLECTED | PASS |
| `/api/requests/{id}/send-next` (collector) | POST | 200 | 200, ProcessingBatch + LabRequest created | PASS |
| `/api/lab-reports` | POST | 200 | 200 `LAB-RPT-2026-0C1B6B` APPROVED | PASS |
| `/api/requests/{id}/send-next` (lab) | POST | 200 | 200, → PACKAGING | PASS |
| `/api/packaging` | POST | 200 | 200 + QR data URI | PASS |
| `/api/requests/{id}` status update | PUT | 401/403 without auth | **200 — unauthenticated state change** | FAIL |
| `/verify/{batch}` valid | GET | 200 verified | 200 `VERIFIED 100% GENUINE HONEY` | PASS |
| `/verify/{batch}` nonexistent | GET | 404/`found:false` | 200 `UNVERIFIED BATCH` (explicit, not crash) | PASS* |
| `/verify` HTML mode | GET | HTML certificate | rendered (browser flow) | PASS |
| `GET /verify/{id}` auth | GET | public by design | public | PASS* (accepted design; note in §16) |
| Legacy `/collection/requests` aliases | GET/POST | 200 | 200 (alias decorators) | PASS |

\* See context in the respective sections.

## 7. Database / Supabase Tests

```
Supabase configuration:  NOT CONFIGURED (plain PostgreSQL in use)
PostgreSQL connection:   CONNECTED (engine=postgresql, latency ~285ms at health check)
DATABASE_URL:            FOUND & CONFIGURED (value withheld)
Database migrations:     CONFIGURED (alembic.ini + alembic/ present; init_db baseline applied)
Required tables:         PRESENT (20 SQLAlchemy models incl. users, profiles, hives,
                         hive_telemetry, hive_ai_analysis, hive_alerts, collection_requests,
                         collection_batches, processing_batches, lab_requests, lab_reports,
                         packaging_batches, blockchain_records, qr_codes, otp_verifications)
Unique constraints:      VERIFIED in practice (duplicate email+role → 409; unique hive_code/device_id assigned)
Relationships:           hive→user ownership enforced at API level (403 on foreign writes)
CRUD:                    CREATE (user/hive/request/batch/report/packaging) PASS
                         READ (profile/hives/requests/verify) PASS
                         UPDATE (profile/requests) PASS
                         DELETE (hive — tested 403 path; owner delete not executed to preserve chain data)
Persistence:             PASS — full batch chain survived a real backend process restart
```

## 8. Authentication Tests

| Test | Result | Evidence |
|---|---|---|
| Email/password registration | PASS | JWT issued, user persisted |
| Email/password login (`emailOrPhone` format used by Flutter) | PASS | 200 + valid JWT |
| Wrong password rejected | PASS | 401 `INVALID_PASSWORD` |
| Unknown user rejected | PASS | 401 `USER_NOT_FOUND` |
| Passwords stored as bcrypt | PASS | direct DB read: `$2b$12$` prefix, 60 chars, not plaintext |
| Legacy SHA-256 hash upgrade path | PASS (code) | `verify_and_update_password` upgrades transparently |
| Google auth endpoint | NOT TESTED | requires real Google ID token |
| OTP send/verify | PASS (sandbox) | `OTP_PROVIDER=sandbox`; OTP returned in log — see §16 |
| Logout / token refresh | NOT TESTED | no refresh endpoint exists; logout is client-side only |
| Session persistence across restart | PARTIAL | token still accepted after restart — but see FAIL in §6: invalid tokens are also accepted |

**FAIL — JWT verification bypass:** `GET /api/profile` with `Authorization: Bearer faketoken.evil.x` returned HTTP 200 with a real user's profile. Root cause in `backend/main.py` → `get_current_user`/`get_optional_current_user` + `get_profile`: on any auth failure the handler falls back to `x-user-id` header and then to `db.query(User).first()`. This defeats token validation for every endpoint that uses the optional/ fallback chain.

## 9. Authorization / Role Isolation

| Test | Expected | Actual | Status |
|---|---|---|---|
| Harvester A updates Harvester B's hive | 403 | 403 `FORBIDDEN` | PASS |
| Harvester A deletes Harvester B's hive | 403 | 403 | PASS |
| LAB account creates hive | 403 | 403 role gate | PASS |
| Collector accepts harvester request | 200 (by design) | 200 | PASS |
| Unauthenticated PUT on request status | 401/403 | **200 — state changed** | FAIL |
| Cross-role read isolation (lab→other lab data, packaging→other business) | isolated | lists are global (`/api/requests`, `/api/hives` return everything to anyone) | FAIL |
| Profile-gated actions (unverified collector) | blocked until profile complete | enforced via `require_verified_*` (verified live: workflows only succeeded after profile completion) | PASS |

## 10. Flutter/UI Tests

| Test | Result | Evidence |
|---|---|---|
| Unit/widget test suite | PASS — 41/41 | `flutter test` → "All tests passed!" |
| Static analysis | PASS — 0 errors/0 warnings (55 info lints in tests) | `flutter analyze` |
| Web build | PASS | `flutter build web` → `√ Built build\web` |
| Web run in Chrome | PASS (app served HTTP 200; backend reachable from browser origin, CORS preflight verified) | earlier session evidence; **backend not running at report time** — see §18 |
| Offline behavior (backend down) | PARTIAL | controllers catch network exceptions and show error/empty states (code-verified in `workflow_controller.dart`, `telemetry_alert_controller.dart`); full manual matrix NOT TESTED |
| Every-screen manual walkthrough | BLOCKED | requires interactive device/emulator session |
| Data consistency DB→API→UI | PARTIAL | field mappings verified in code (e.g., `status`, `batchId`, `hiveCode` naming aligned); live UI diff not captured |

## 11. Real Data Tests

Live pipeline executed **with real persisted data** (no mocks used in the audit):

1. Registered 5 real users (harvester ×2, collector, lab, packaging) → rows in `users`.
2. Harvester created hive `HIVE-0A426C` → row in `hives` with unique code + device mapping `SIH_HIVE_426C`.
3. Telemetry ingested (36.5 °C / 60 % / 21.4 kg) → row in `hive_telemetry`, values preserved exactly.
4. MQTT AI-format payload (41.6 °C, CRITICAL) published to `honeychain/hive/processed` → row in `hive_telemetry` with exact values + CRITICAL row in `hive_alerts` → served back via `/api/telemetry/live/{hive_id}` and `/api/telemetry/alerts`.
5. Collection request `REQ-COL-2026-CFDEFF` → batch `HC-BATCH-2026-B470DC` created with blockchain record.
6. Accept → Process (quantities 15.2→14.8 preserved) → Lab report `LAB-RPT-2026-0C1B6B` → Package (29 jars) → `/verify` returns full chain with all stored values.

Timestamps, IDs, and sensor values were preserved at every hop (verified via API responses above). **No step substituted defaults.**

## 12. Dummy/Mock Data Findings

| File | Location | Type | Impact | Recommended action |
|---|---|---|---|---|
| `backend/main.py` | lifespan seed (`Seed default verified entities…`) | 3 collection centres, 1 lab user, 1 lab, 3 packaging facilities hardcoded | Medium — appear as "real" centres in nearest-centre lookup | Gate behind explicit `SEED_DEMO_DATA=true` env flag |
| `backend/main.py:2856` | `GET /api/verify/harvester/{id}` | always returns `"Certified Beekeeper", VERIFIED` for **any** ID | High — public endpoint returns fake verification | Return 404/`found:false` unless record exists |
| `backend/main.py` | `handle_generic_verification` (`/api/verification/{role}/{step}`) | marks **any** user `is_verified=True` on any step submission | High — verification gate can be self-served by API call | Implement real per-step state tracking |
| `backend/main.py` | `/api/verification/send-otp` | OTP stored but **never SMS-dispatched**; logged in plaintext | High (sandbox-only realism) | Integrate real SMS provider; stop logging OTP |
| `backend/main.py` | `/api/lab-reports` | defaults `overall_result="PASS"` hardcoded; quality values have baked-in defaults | Medium — a report with no real measurements still certifies PASS | Require all measured params; compute PASS/FAIL from thresholds |
| `backend/main.py` | `qr_service` fallback content | verifier renders "No data available yet." placeholders | Low — honest placeholder, not fake data | Acceptable |
| `mobile_app/lib/core/localization/localization_service.dart` | 23× `dummy_sample` | localization *key name* only | None | Rename key |
| `mobile_app/lib/core/widgets/auto_image_slider.dart` | color placeholder | image error fallback | None | Acceptable |

**Verdict:** the primary chain (auth → hives → requests → batches → lab → packaging → QR) runs on real FastAPI → PostgreSQL data as required. The verification/KYC subsystem and seed entities contain hardcoded/simulated behavior as listed above.

## 13. Blockchain Tests

| Test | Result | Evidence |
|---|---|---|
| Contract tests (Solidity/Hardhat) | PASS — 4/4 | `testRecordEvent`, `testOwnerIsDeployer`, `testMultiStepProvenanceTimeline`, `testHarvesterVerification` |
| Deploy script syntax | PASS | `node --check` clean |
| Contract functions present | PASS | `recordEvent`, `getEvents`, `recordHarvesterVerification` |
| Network config (Amoy + localhost) | CONFIGURED | `hardhat.config.js` |
| Deployed address | LOCAL TEST ONLY | `deployed_address.txt` holds a Hardhat localhost address |
| Backend on-chain writes | **NOT CONFIGURED (offline-safe mode)** | `BLOCKCHAIN_PRIVATE_KEY` absent → `blockchain_service` logs tamper-evident SHA-256 hashes and marks events `PENDING`; E2E chain produced hash records with `tx_hash: null` |
| Transaction receipt / hash verification | BLOCKED | no funded wallet/RPC available in this environment |

Blockchain integrity design (hash chaining, offline fallback) works as coded; **no transaction was ever committed to a real chain** during this audit.

## 14. QR / Traceability Tests

| Test | Result | Evidence |
|---|---|---|
| Full chain QR | PASS | `/verify/HC-BATCH-2026-B470DC` → `VERIFIED 100% GENUINE HONEY` with harvester, telemetry, AI, processing, lab (reportId), packaging, blockchain events — all matching stored DB values |
| Nonexistent batch QR | PASS* | returns explicit `UNVERIFIED BATCH` / `found:false` (HTTP 200; acceptable, not a crash or fake data) |
| Repeated verification ×3 | PASS | identical responses (stable) |
| QR image generation | PASS | base64 data URI returned by `/api/packaging` |
| Duplicate QR | PASS | `QRCode` row keyed by batch_id, reused not duplicated |
| Tamper evidence | PARTIAL | events recorded with SHA-256 hashes but `PENDING` (no chain) — hashes present, on-chain anchoring absent |

## 15. AI/ML Integration Tests

Interface-level only. **The `ai_ml` folder was not modified during this audit** (see §21 for pre-existing modifications from an earlier, separate task).

| Test | Result | Evidence |
|---|---|---|
| Output formatter contract | PASS | `build_app_json` produces `device_id`, `timestamp`, `hive_status.{risk_level,status,anomaly_detected,anomaly_score}`, `sensors.{temperature_c,humidity_pct,weight_kg,acoustics_hz}` — exactly the keys `backend/services/mqtt_consumer.py` reads; no field corruption |
| End-to-end MQTT → backend → DB | PASS | published AI-format payload on `honeychain/hive/processed`; telemetry + CRITICAL alert persisted with exact values |
| Model artifacts | PRESENT | `ai_ml/models/honeychain_isolation_forest.joblib` + `threshold.json` (not retrained — out of scope) |
| `ai_ml/config.py` topic constant | NOTE | previously stale topic corrected in an earlier session; processor uses env `MQTT_INPUT_TOPIC`/`MQTT_OUTPUT_TOPIC` |
| LSTM autoencoder | NOT TESTED | training scripts only; requires torch training run — out of scope |

Reported (not fixed, per scope): none new this session; the pipeline interface is healthy.

## 16. Security Findings

| # | Severity | Finding |
|---|---|---|
| S1 | CRITICAL | JWT verification bypass + identity fallback chain (`get_optional_current_user`, `get_profile` → `db.query(User).first()`, `x-user-id` header). Forged/no token returns real profiles. |
| S2 | CRITICAL | `PUT /api/requests/{id}` has **no authentication dependency** — unauthenticated supply-chain state tampering proven live. |
| S3 | HIGH | `GET /api/hives`, `GET /api/requests`, `/api/telemetry/*` readable without auth — full cross-tenant supply-chain disclosure. |
| S4 | HIGH | OTP codes logged in plaintext (`[OTP Service] Generated real OTP …`) and never dispatched via SMS. |
| S5 | HIGH | Self-service verification: any user can flip `is_verified=True` via generic verification endpoint. |
| S6 | MEDIUM | Default JWT secret fallback `honeychain-production-secure-jwt-key-2026` hardcoded in `main.py`; no startup guard rejecting default secret in production. |
| S7 | MEDIUM | Firebase Web API key committed in `mobile_app/lib/firebase_options.dart` — standard for Firebase web apps but should be paired with App Check / restrictions. SECURITY ISSUE — secret detected in `firebase_options.dart` (value not reproduced). |
| S8 | LOW | Password reset returns `devToken` in the API response (dev convenience, dangerous if left enabled). |
| S9 | INFO | CORS `allow_origins=["*"]` with `allow_credentials=True`. |
| S10 | PASS-area | No `.env` tracked in git (`git ls-files` clean); bcrypt password storage confirmed; no private keys in `backend/`. |

## 17. Failed Tests

1. **JWT bypass / profile leak**
   - Expected: 401 for forged token; Actual: 200 + foreign profile
   - File: `backend/main.py` (`get_current_user`, `get_optional_current_user`, `get_profile`)
   - Cause: fallback to `x-user-id` header and first-DB-user lookup
   - Next action: remove fallbacks; `get_optional_current_user` must return None on invalid token; `/api/profile` requires a resolved user.

2. **Unauthenticated request-state tampering**
   - Expected: 401; Actual: 200 "Request updated to DENIED"
   - File: `backend/main.py` → `update_workflow_request` (`PUT /api/requests/{id}`)
   - Cause: missing `Depends(get_current_user)` + role check
   - Next action: add auth + role authorization + state-machine validation (no transitions from terminal states).

3. **Global data exposure on list endpoints** (`/api/hives`, `/api/requests`, telemetry)
   - Expected: caller-scoped lists; Actual: full tables returned unauthenticated
   - Next action: require auth; filter by role/ownership.

4. **`python main.py` exits silently**
   - File: `backend/main.py` (no `if __name__ == "__main__": uvicorn.run(...)`)
   - Next action: add entrypoint (matches `scripts/start_dev.sh` expectations).

5. **Nonexistent batch QR returns HTTP 200** (design smell, not data corruption)
   - Next action: return 404 for unknown batch IDs (keep JSON body for consumers).

6. **Verification endpoints auto-approve** (see §12 rows 3–5) — treats simulated KYC as real.

7. **Blockchain writes never reach a chain** — expected given missing key; flagged NOT CONFIGURED rather than FAIL of logic.

8. **Flutter web session down at report time** — the debug web server from the earlier session is no longer running (HTTP 000); app itself passed build/serve checks earlier. Restart required for live viewing.

9. **`/api/verify/harvester/{id}` always VERIFIED** — fake positive for any ID (see §12).

## 18. Blocked Tests

| Test | Blocker |
|---|---|
| Google authentication | Requires real Google ID token / Firebase project config |
| Real SMS OTP delivery | No SMS provider credentials (`OTP_PROVIDER=sandbox`) |
| On-chain transactions + receipt verification | No funded wallet / RPC (`BLOCKCHAIN_PRIVATE_KEY` unset); no Amoy access from this environment |
| Supabase-specific features | Supabase not configured (plain PostgreSQL) |
| ESP32 firmware execution | Requires physical hardware |
| Full interactive UI walkthrough | Requires human/device session (automated suite + build/run checks done instead) |
| Load testing | Out of scope per instructions (only light repeated-request checks performed) |
| LSTM training pipeline | Requires torch training run + dataset; out of audit scope |

## 19. Remaining Work (dependency order)

1. Fix S1/S2/S3 (auth bypass, unauthenticated mutation, data exposure) — pure backend changes, highest urgency.
2. Wire real verification: remove auto-verify + fake harvester verifier; per-step state machine for KYC.
3. Add `__main__` uvicorn entrypoint; enforce non-default `JWT_SECRET_KEY` at startup; remove `devToken` in production mode; stop OTP logging.
4. Configure `BLOCKCHAIN_PRIVATE_KEY` + RPC (or Amoy) so provenance anchors on-chain instead of PENDING hashes.
5. Gate seed data behind an env flag; require real lab measurements for PASS certification.
6. Restart Flutter web session for interactive UI pass; add integration tests with mock HTTP for offline paths.

## 20. Files Modified

**None.** This audit was executed entirely in read/execute mode against the repository; all testing was done through live HTTP, MQTT, pytest, hardhat, flutter test, and read-only DB queries. No source file was changed during this task.

## 21. AI/ML Protection Confirmation

```
AI/ML Protection:
The ai_ml folder was not modified during this testing task.
```

Note for transparency: `git status` shows pre-existing modifications in `ai_ml/config.py` and `ai_ml/mqtt/mqtt_processor.py` (MQTT credential support) plus untracked `ai_ml/Dockerfile` and model artifacts — all created during the earlier, separate integration session (documented in `FIX_IMPLEMENTATION_REPORT.md`), not during this audit.
