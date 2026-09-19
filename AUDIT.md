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
