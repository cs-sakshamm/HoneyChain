# HoneyChain — Engineering Audit (JS → TS Migration & Controlled Cleanup)

**Date:** 2026-09-20 · **Branch:** `main` · **Scope:** behavior-preserving audit, JS→TS migration, proven-unused cleanup, documentation, validation.

---

## 1. Codebase Audit Summary

| Layer | Technology | JS/JSX files (pre) | TS/TSX (pre) | Migration |
|---|---|---|---|---|
| `blockchain/` | Hardhat 3 + ethers 6 + node:test | 5 `.js` | 2 `.d.ts` (generated) | **5 → 5 `.ts`** |
| `web/` | Vite + React 18 | 0 | 14 `.ts`/`.tsx` | none needed (already TS) |
| `backend/` | Python/FastAPI | 0 | — | N/A |
| `mobile_app/` | Flutter/Dart | 0 | — | N/A |
| `ai_ml/` | Python | 0 | — | **UNTOUCHED (read-only)** |
| `legacy/` | TS + JS (superseded Node backend) | 1 `.js` | 20+ `.ts` | **REMOVED from the repository** — verified unreferenced by any active layer; recoverable via tag `legacy-express-backend-archive` |

**Active JS inventory detail (blockchain/):** `hardhat.config.js`, `compile_and_deploy.js`, `scripts/deploy.js`, `scripts/verify_backend_evm.js`, `test/provenance.test.js`. All consumed: config (Hardhat), scripts (`npm run`), test (`npm test`). Dynamic-import/lazy-load/route references: none found (`git grep` across configs, docs, scripts).

## 2. Migration Summary

```text
Total JS files found (active layers):        5
Total JSX files found:                       0
Total JS  → TS:                              5
Total JSX → TSX:                             0
Files deleted:                               5 (the migrated .js originals)
Duplicate files removed:                     0 (no .js/.ts duplicates retained)
Dead code removed:                           2 orphaned one-shot doc generators
                                             (scripts/generate_docs.py,
                                              scripts/generate_report.py — no references
                                             in any script, config, or doc; outputs
                                             already committed in docs/)
Dependencies changed:                        +typescript ^5.5.3, +@types/node ^22.10.0
                                             (blockchain devDependencies — required by
                                             the migration; no upgrades of unrelated deps)
Configuration changes:                       + blockchain/tsconfig.json (strict, noEmit —
                                             Node 22 executes TS via native type stripping,
                                             so no build step was introduced);
                                             package.json scripts repointed to .ts
                                             (test, test:backend-evm, deploy, +typecheck)
```

**Migration guarantees:** identical business logic, execution order, env-var handling (`process.env.POLYGON_AMOY_RPC_URL`/`BLOCKCHAIN_PRIVATE_KEY` fallbacks preserved), API/output strings, error handling, and exit codes. Types added are minimal and structural (`SolcOutput`, contract method interface in the test, `as never` casts only at the untyped-ABI boundary — no `@ts-ignore`, no broad `any`).

## 3. Safe Cleanup

| Item | Decision | Evidence |
|---|---|---|
| `scripts/generate_docs.py`, `scripts/generate_report.py` | **REMOVED** | zero references (`git grep` over `.py/.md/.json/.ps1/.sh/.json`); docs they generated are already committed |
| `ml_models_backup/` (metrics.json, threshold.json) | **KEPT** | referenced by `ai_ml/` (`mqtt_processor.py`, training scripts, `ai_ml/README.md`) |
| `legacy/` (express_backend*, express_backend_prisma — 94 tracked files, ~1.2 MB) | **REMOVED** (2026-09-20) | final verification before removal: no code/script/build/CI/docker references (`.dockerignore` exclusion deleted as inert); recovery point: tag `legacy-express-backend-archive` |
| `mobile_app` controller methods (`fetchHiveStatus`, `fetchHiveTelemetryHistory`, `ingestSensorData`) | **KEPT** | public controller API surface; `fetchHiveStatus`/dashboard paths are exercised in tests; removal would risk behavior |
| `scripts/start_dev.ps1` / `start_dev.sh`, `web/dist` | **KEPT** | local tooling; `web/dist` untracked |

## 4. Animation

```text
Mobile framework:      Flutter/Dart
Framer Motion:         NOT APPLICABLE — Mobile app uses Flutter/Dart.
Framer Motion installed: NO (mobile) — already present in web/ verifier (^13.4.0, pre-existing)
Animations added:      NONE
Screens/components animated: none
Behavior changes:      NONE
```

Rationale: forcing a JS animation library into Flutter is technically invalid, and adding a parallel Flutter animation layer was not authorized by any functional gap — the app already uses Material 3 transitions and progress indicators (documented in `mobile_app/README.md` §7).

## 5. Documentation Summary

```text
mobile_app/README.md:   UPDATED (rewritten to actual architecture: Provider, Firebase,
                        real telemetry dashboard states, real test counts, Framer Motion N/A)
backend/README.md:      UPDATED (rewritten: Supabase PostgreSQL authoritative, real /api route
                        inventory, MQTT validation/idempotency, JWT-authenticated WebSockets,
                        removed stale Express/Prisma-in-backend claims, env names only,
                        removed a hardcoded example private key from the old version)
blockchain/README.md:   UPDATED (rewritten: TS toolchain, real contract surface, on-chain vs
                        off-chain table, tamper-evidence principle stated, real commands)
blockchain/REQUIREMENT.txt: UPDATED (Node ≥ 22.7, TS ^5.5, @types/node, hardhat.config.ts)
mobile_app/REQUIREMENT.txt: VERIFIED — already matches pubspec.yaml exactly (no change)
Root README.md:         CORRECTED (DATABASE_URL placeholder no longer implies localhost Postgres)
docs/DEPLOYMENT.md:     CORRECTED (deploy command → node scripts/deploy.ts)
docs/README.md:         CORRECTED (sequence diagram DB → Supabase PostgreSQL)
docs/WINDOWS_DEMO_RUNBOOK.md: CORRECTED (2× DATABASE_URL placeholders)
ai_ml/README.md:        NOT TOUCHED
ai_ml/:                 NOT TOUCHED
No duplicate requirements file created (per-layer REQUIREMENT.txt files are the source of truth)
```

No invented endpoints/contracts/commands: every README statement was derived from `backend/main.py` route decorators, `models.py`, the contract source, `pubspec.yaml`, `package.json`, and executed commands.

## 6. Validation (all executed in this session)

```text
TypeScript (blockchain tsc --noEmit):        PASS
Lint (flutter analyze):                      PASS (0 errors; pre-existing warnings only)
Tests — backend (pytest backend/tests):      PASS (26/26, incl. 8 public-verify content-negotiation tests added after the migration;
                                             re-verified after §8.1/§8.2 fixes)
Tests — AI/ML (pytest ai_ml/tests):          PASS (10/10, read-only run)
Tests — blockchain (npm test):               PASS (1/1)
Tests — Flutter (flutter test):              PASS (49/49 at migration time; 47/47 after
                                             removing 2 tests of the deleted role-switcher
                                             model, see §8.2)
Build — web (tsc && vite build):             PASS
Build — blockchain (npx hardhat compile):    PASS
Integration — backend ↔ EVM service check:   PASS (Backend EVM service check passed: 0xddd7…)
Application startup (FastAPI on Supabase):   PASS (earlier this session: /api/health HEALTHY,
                                             engine postgresql; MQTT consumer start/stop clean)
Mobile app startup:                          PASS (49/49 incl. full-app smoke render test)
Animation validation:                        NOT VERIFIED — no animation changes were made
Documentation consistency:                   PASS (cross-checked READMEs ↔ code ↔ configs;
                                             stale .js/SQLite/localhost claims fixed, see §5)
```

Baseline comparison (pre-migration): blockchain test 1/1 PASS, web build PASS, ai_ml 10/10 — **no regressions; before behavior = after behavior.**

## 7. Known Issues / Notes

* ~~`legacy/` remains in-tree, unreferenced~~ → **resolved:** removed from the repository (94 files, ~1.2 MB) after full reference verification; recoverable at tag `legacy-express-backend-archive`.
* `scripts/start_dev.ps1` is UTF-16 encoded; works with PowerShell but is inconsistent with the repo's UTF-8 convention (left untouched — functioning tooling).
* The web verifier ships a `framer-motion` dependency already in use by its components (pre-existing; verified via `web/src/utils/animations.ts` usage) — unchanged.
* ~~`mobile_app` `AppConstants.publicVerificationBaseUrl` defaults to a temporary trycloudflare host~~ → **resolved:** QR URLs now default to `backendBaseUrl` (the FastAPI backend serves `/verify/{batch_id}` with HTML/JSON content negotiation); build-time `--dart-define=PUBLIC_VERIFY_URL` override retained.

## 8. Maintenance Fixes (behavior-preserving, this session)

### 8.1 `datetime.utcnow()` deprecation — FIXED
* 21 call sites (`datetime.utcnow()` / `datetime.utcfromtimestamp()`) in `backend/main.py` + `backend/services/mqtt_consumer.py` replaced with TZ-independent epoch-based helpers (`_utcnow()` / `_utcfromts()`).
* **Behavior-identical:** helpers return the same naive-UTC datetimes the project stores (no aware/naive comparison drift); verified correct under `TZ=America/New_York` and epoch equality.
* Pytest deprecation warnings dropped 328 → 254; **backend suite 26/26 PASS** post-change.
* `ai_ml/` inspected only — **not modified** (its internal `utcnow` usage is out of scope by rule).

### 8.2 "Switch Account" removal — FIXED (spec-mandated)
The multi-role account switcher allowed a logged-in user to mint/enter another role's account by email (frontend-selected role context) — an authorization-isolation hazard, removed end-to-end:
* `mobile_app/profile_screen.dart`: role-switcher card + `_buildRoleAccountsCard` builder + `fetchRoleAccounts()` call removed (~205 lines). Logout and all other profile features intact.
* `mobile_app/user_controller.dart`: `switchAccountRole()`, `fetchRoleAccounts()`, `roleAccounts` state, and the `RoleAccountSummary` model removed. **`switchRole()` retained** — it is the signup-time role selection used by `role_selection_screen.dart`, not account switching.
* `backend/main.py`: `POST /api/auth/switch-role` and `GET /api/auth/accounts` routes, `SwitchRoleRequest` model, and the now-unreferenced `get_optional_current_user` helper removed (~155 lines). Real auth (`get_current_user`-protected routes), OTP, Google login untouched.
* Tests referencing the removed model updated (`avatar_test.dart`, `role_decoupled_accounts_test.dart` — removed only the 2 dead cases; all other assertions retained).
* `git grep` for `switch.?account|switchrole|role.?switcher` across code: only the retained signup-path `switchRole` remains.
* **Verification:** backend 26/26 PASS, Flutter analyze 0 errors/warnings, **Flutter 47/47 PASS**.

## 9. HoneyChain Specification Compliance Audit

Full-repo scans against the traceability/auth specification (2026-09-20):

| Area | Result | Evidence |
|---|---|---|
| Fake auth / hardcoded creds (§15B) | PASS | `git grep` for demo/test/admin accounts, hardcoded passwords, fake/mock tokens, auth-constant bypasses: **0 hits** in active code |
| Password storage & verification (§15) | PASS | bcrypt cost-12 (`backend/main.py` `hash_password`); legacy SHA-256 hashes transparently upgraded to bcrypt on successful login; no plaintext comparison or hash exposure found |
| Switch Account removal (§17) | FIXED | Removed end-to-end this session (see §8.2): profile UI, controller methods/model, backend routes |
| Document hashing (§11) | FIXED | Lab-report SHA-256 anchoring was correct; but the **public harvester verification lookup fabricated integrity claims** — the mobile UI rendered success-styled 'Integrity Verified: Verified', 'Approved & Blockchain Recorded ✓' and a hardcoded ledger name the backend never sends. Fixed: backend returns only real fields, model parses the nested `harvester` object without fake fallbacks, UI renders integrity only when a hash comparison actually occurred. Pinned by 3 new tests |
| Misleading blockchain claims (§2) | PASS | No 'guaranteed authentic/100% pure' wording in code/UI/docs; verifier text already reflects tamper-evidence, not physical-world truth |
| Dummy/mock data in production screens (§19) | PASS | No dummy/mock/fake/placeholder data in `mobile_app/lib`, `web/src`, or backend routes |
| Stage-transition & role guards (§10, §12–§14) | PASS (pre-existing) | `test_supply_chain_guards.py`: cross-role lab accept → 403, packaging after failed lab → blocked, duplicate collection request → blocked; full happy-path e2e (`test_e2e_integration.py`) |
| Contract-level enforcement (§27–§28) | PASS (pre-existing) | `HoneyChainProvenance.sol`: owner-only `recordEvent`, non-empty verification/record-hash requires; backend is the authorized actor |
| Batch ID consistency (§4) | PASS (pre-existing) | Single `CollectionBatch.batch_id` flows through request/accept/lab/packaging; e2e test asserts the same batch id end-to-end |
| On-chain vs off-chain (§6) | PASS (pre-existing) | Only hashes + structured event payloads go on-chain; lab documents stay off-chain (hash anchored) |

Validation after fixes: backend **34/34** (incl. 3 new harvester-verification tests), Flutter **47/47**, `ai_ml/` untouched.

## 10. Batch ID Chain Integrity (spec §4/§13/§21/§22)

New test file `backend/tests/test_batch_id_chain.py` (8 tests) pins one batch ID across HARVEST → COLLECTION → PROCESSING → LAB_TEST → PACKAGING → QR verification, including DB row linkage and blockchain-record linkage for the same chain. Running it surfaced **two real backend bugs, both fixed**:

1. **Harvest accepted a nonexistent hive** (`backend/main.py` `/api/harvests`) — the IDOR check only rejected *other users'* hives; a nonexistent hive passed, then died as an unhandled FK `IntegrityError` (500). Now returns a clean **404 `HIVE_NOT_FOUND`** (spec §7/§23).
2. **Stage responses omitted `batchId`** — `/api/processing` and `/api/lab-reports` returned without the batch ID, so clients couldn't tie stage results back to the chain (spec §4). Both responses now include it (purely additive keys).

Also corrected during verification: the blockchain-record assertion initially required `tx_hash` on every record; the service's designed offline degradation is `status=PENDING, tx_hash=None`, so the test now requires `data_hash` always and `tx_hash` iff `CONFIRMED`.

Result: batch chain **8/8 PASS**, full backend suite **42/42 PASS**.

## 11. Stage-Transition Matrix (spec §13/§14/§30)

New test file `backend/tests/test_stage_transition_matrix.py` (26 tests) exhaustively pins the lifecycle state machine:

| Class | Pins |
|---|---|
| `TestInvalidStageJumps` (9) | Processing before accept → 409 `INVALID_STAGE`; lab report with no lab request → `LAB_REQUEST_MISSING`; report before lab accepts → `INVALID_STAGE`; packaging with no prior stages → `PACKAGING_NOT_PERMITTED` naming missing predecessors; packaging after FAILED lab → `LAB_TEST_FAILED`; send-to-lab before accept → `INVALID_STATE`; duplicate collection request → `DUPLICATE_REQUEST`; **re-harvest cannot rewind an in-flight batch → `INVALID_STAGE`** (§13 PROCESSING→HARVEST); **second lab report cannot flip certification → `DUPLICATE_REPORT`** |
| `TestRoleMatrix` (8) | Non-harvester request creation, harvester/lab accepting collection requests, wrong-lab accepting an assigned request, harvester/collector/packager creating lab reports, non-packager packaging, harvester dispatching to lab, `PUBLIC_CONSUMER` advancing anything — all → 403 `FORBIDDEN` |
| `TestStateMachineNegatives` (5) | Double accept (collection + lab) → `DUPLICATE_ACCEPT`; reject-then-accept → `INVALID_STATE`; dispatch after failed report → `LAB_TEST_FAILED`; report missing required physicochemical values → 422 `VALIDATION_ERROR` (no fabricated certification) |

Two contract behaviors documented during verification (not bugs — explicitly implemented rules, now pinned):

- **Packaging accepts PASSED-but-undispatched batches**: the §12 gate requires HARVEST+COLLECTION+PROCESSING+LAB_TEST PASSED + authorized packager; an explicit lab dispatch is not part of the gate (`APPROVED` is in the accept allowlist).
- **Duplicate lab dispatch surfaces as `INVALID_STATE`**: after the first dispatch the collection request leaves `ACCEPTED`, so the state guard fires before the duplicate-request check — layered defense, same 409.

Both new §13 guards (re-harvest rewind block, duplicate-report block) were added earlier this session and are exercised by this matrix for the first time.

Result: matrix **26/26 PASS**, full backend suite **68/68 PASS**, `ai_ml/` untouched.
