# HoneyChain — Complete Project Audit, Integration & Production Readiness Analysis

**Audit Date:** September 16, 2026  
**Auditor Roles:** Senior Full-Stack Engineer, Software Architect, DevOps Engineer, Database Engineer, Security Engineer, AI/ML Integration Engineer, Blockchain Engineer, Flutter Engineer, QA Engineer, and Code Reviewer.  
**Scope:** Complete repository analysis (`mobile_app/`, `backend/`, `blockchain/`, `ai_ml/`, `iot/`, `mosquitto/`, configuration, databases, tests, security, deployment).  
**AI/ML Policy:** Strictly inspected and analyzed without modification.

---

## 1. Executive Summary & Architecture Pipeline

### Intended Architectural Flow

```
ESP32 / IoT Edge Sensors (DHT22, HX711, INMP441)
              ↓ MQTT: "honeychain/hive/telemetry"
       Mosquitto Broker (Port 1883)
              ↓
  AI/ML Inference Service (Isolation Forest + Temporal Risk Engine)
              ↓ MQTT: "honeychain/hive/processed"
   Backend MQTT Consumer (paho-mqtt worker in FastAPI)
              ↓
Relational Database (PostgreSQL 16 / SQLAlchemy 2.0)
              ↓
  Web3 Blockchain Provenance Service (EVM Smart Contract)
              ↓
FastAPI Server (Port 8000) ←→ Real-Time WebSockets (`/ws/telemetry`)
              ↓
     Flutter Mobile Application (Android / iOS / Web)
     ├── Harvester (Add Hive, Telemetry Alerts, Collection Request)
     ├── Collection & Processing (Centrifugal Extraction, Batch Creation)
     ├── Analytical Lab (Moisture, HMF, Diastase, Purity Certification)
     └── Packaging (Tamper-Evident Induction Seal, Final Batch QR)
              ↓
Final Consumer Public Verification (`/verify/{batch_id}`)
```

### Actual Implementation Gap Analysis

1. **Dual Split Backend Architecture:** The repository contains two competing backends: a Python FastAPI server (`backend/main.py`) and a Node.js/TypeScript Express server (`backend/src/`). The Flutter mobile app hardcodes its base URL to `http://127.0.0.1:8000` (FastAPI), but several essential endpoints (`/api/auth/accounts`, `/api/auth/switch-role`, `/api/auth/forgot-password`) and verification services exist only in the Express service.
2. **Database Divergence:** FastAPI connects to PostgreSQL/SQLite via SQLAlchemy (`models.py`), while Express connects to a local SQLite file (`prisma/dev.db`) via Prisma (`schema.prisma`). They use completely different naming conventions (`snake_case` vs. `camelCase`) and do not share state.
3. **Authentication & Authorization Bypass:** The FastAPI `/api/auth/login` endpoint does **not** validate passwords, does **not** parse Flutter's `emailOrPhone` payload (resulting in auto-generated fallback accounts), and issues dummy tokens (`jwt-<uuid>`) that are never verified by any route middleware.
4. **Profile Completion Gate Gap:** While the Flutter app enforces `ProfileGuard` on the UI, the FastAPI backend has **zero** profile completion or verification checks on `/api/hives`, `/api/requests`, `/api/harvests`, `/api/processing`, `/api/lab-reports`, or `/api/packaging`. Any anonymous caller can trigger any supply chain transition.
5. **Raw Telemetry Black Hole:** When raw telemetry arrives on `honeychain/hive/telemetry`, the backend consumer ignores it with a debug log. If the AI/ML service is stopped, down, or waiting for its 24-hour baseline (145 readings), **zero telemetry is recorded in the database**.
6. **WebSocket Threading Bug:** The MQTT background thread invokes `asyncio.run(manager.broadcast(data))` to broadcast to WebSockets created on FastAPI's main event loop. This causes `RuntimeError` on active connections.
7. **Blockchain Synchronous Hang:** `Web3.HTTPProvider` has no connection timeout set. Whenever the local Hardhat node or blockchain RPC is offline, every supply chain write hangs for 20+ seconds while timing out before falling back to off-chain hashes.
8. **Broken Smart Contract Deploy Script:** `blockchain/scripts/deploy.js` contains an unquoted syntax error: `console.log(HoneyChainProvenance deployed to );`.

---

## 2. Complete Implementation Status Table

| Module | Feature | Status | Evidence | Problem | Required Work | Priority |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Backend** | Python FastAPI Core | **DONE** | `backend/main.py` | Runs REST & WebSocket endpoints on port 8000 | Unify with TypeScript services | **MEDIUM** |
| **Backend** | User Authentication (Login) | **BROKEN** | `backend/main.py:426-455` | Ignores password, expects `email`/`phone` while Flutter sends `emailOrPhone`, auto-creates dummy user on login | Validate passwords with bcrypt, parse `emailOrPhone`, return valid JWT | **CRITICAL** |
| **Backend** | JWT Token Handling | **BROKEN** | `backend/main.py:454` | Returns fake string `jwt-<uuid>`. No token validation middleware on any endpoint | Implement standard HMAC-SHA256 JWT generation and FastAPI `OAuth2PasswordBearer` dependency | **CRITICAL** |
| **Backend** | Role Accounts Switch | **MISSING** | `mobile_app/lib/features/profile/controllers/user_controller.dart:467,488` | Flutter calls `/api/auth/accounts` and `/api/auth/switch-role`, but neither exists in `backend/main.py` (404) | Port multi-role account discovery and switching endpoints from Express to FastAPI | **HIGH** |
| **Backend** | Profile Completion Gate | **BROKEN** | `backend/main.py:581,951,1397` | FastAPI backend allows unverified users to create hives, batches, and lab reports without profile checks | Implement server-side role validation middleware checking `user.is_verified` and mandatory profile fields | **CRITICAL** |
| **Backend** | Telemetry Ingestion (REST) | **DONE** | `backend/main.py:675` | `POST /api/telemetry/ingest` persists readings and triggers critical alerts | Add rate limiting and device authentication | **MEDIUM** |
| **Backend** | MQTT Raw Telemetry Ingestion | **BROKEN** | `backend/services/mqtt_consumer.py:58` | Subscribes to `honeychain/hive/telemetry` but only calls `logger.debug()`. Does not save to database | Persist raw sensor packets to `HiveTelemetry` even when AI processor is offline | **HIGH** |
| **Backend** | WebSocket Broadcast | **BROKEN** | `backend/main.py:183` | `asyncio.run(manager.broadcast(data))` called from background MQTT thread raises `RuntimeError` | Use `asyncio.run_coroutine_threadsafe(manager.broadcast(data), loop)` | **HIGH** |
| **Backend** | Public Batch Verification | **DONE** | `backend/main.py:1687-1796` | `/verify/{batch_id}` renders HTML for browsers and JSON for Flutter | Update base verification URL from `127.0.0.1` to production domain | **HIGH** |
| **Database** | PostgreSQL Relational Schema | **PARTIAL** | `backend/models.py`, `backend/database.py` | 20 SQLAlchemy models exist, but DB falls back to SQLite `honeychain.db` because Docker Postgres is offline | Deploy and migrate cloud PostgreSQL; configure SSL and connection pool | **CRITICAL** |
| **Database** | Database Migrations | **BROKEN** | `backend/database.py:51-72` | No Alembic migration setup; uses fragile runtime `ALTER TABLE ADD COLUMN` queries | Initialize Alembic migrations for declarative, reversible schema migrations | **HIGH** |
| **Blockchain** | Solidity Smart Contract | **DONE** | `blockchain/contracts/HoneyChainProvenance.sol` | Contains `recordEvent`, `getEvents`, and `recordHarvesterVerification` | Add role-based access modifiers for Lab and Packaging roles | **MEDIUM** |
| **Blockchain** | Deploy Script | **BROKEN** | `blockchain/scripts/deploy.js:7` | Line 7: `console.log(HoneyChainProvenance deployed to );` throws `SyntaxError` | Fix string literal and write deployed address to shared config | **HIGH** |
| **Blockchain** | Polygon Amoy Configuration | **MISSING** | `blockchain/hardhat.config.js` | Only `localhost:8545` configured; no Polygon Amoy RPC, chain ID, or faucet wallet | Add `amoy` network config with Alchemy/Infura RPC and testnet gas wallet | **HIGH** |
| **Blockchain** | Web3 Integration Service | **PARTIAL** | `backend/services/blockchain_service.py` | Web3.py records batch events, but synchronous calls block for 20s when node is offline | Add explicit 2-second timeout to HTTPProvider and async transaction submission | **HIGH** |
| **AI/ML** | Anomaly Detection Model | **DONE** | `ai_ml/models/honeychain_isolation_forest.joblib` | Isolation Forest trained on 485 multi-sensor readings | Cold start requires 145 readings; needs fallback heuristic for new hives | **MEDIUM** |
| **AI/ML** | MQTT AI Pipeline | **DONE** | `ai_ml/mqtt/mqtt_processor.py` | Subscribes to telemetry, computes temporal rolling features, publishes to processed topic | Depends on active MQTT broker running | **MEDIUM** |
| **IoT / Edge** | ESP32 Firmware Source | **MISSING** | `iot/` directory | Only documentation and requirements exist. Zero `.ino` or C++ firmware files present | Implement reference Arduino/PlatformIO C++ sketch for ESP32 with DHT22, HX711, INMP441 | **HIGH** |
| **Mobile App** | Login & Registration | **DONE** | `mobile_app/lib/features/authentication/` | Clean UI, 3-tier avatar support, Google sign-in integration, 4 role stages | Fix payload mapping (`emailOrPhone` vs `email`/`phone`) | **HIGH** |
| **Mobile App** | Hive Telemetry & Charts | **DONE** | `mobile_app/lib/features/hives/` | Displays real-time metrics, inspection status, dynamic health badges | Connect WebSocket streaming directly to charts | **MEDIUM** |
| **Mobile App** | Harvester Supply Workflow | **DONE** | `mobile_app/lib/features/collection/` | Nearest center discovery (Haversine formula), collection requests | Integrate real user geolocation from device GPS | **MEDIUM** |
| **Mobile App** | Lab Certification Flow | **DONE** | `mobile_app/lib/features/lab/` | Physicochemical parameter validation (moisture, HMF, diastase, pollen) | Enforce digital signature hash on lab report | **MEDIUM** |
| **Mobile App** | Packaging & Final QR Display | **DONE** | `mobile_app/lib/features/packaging/` | Renders Base64 QR code and triggers batch completion | Test on physical devices with camera scanner | **MEDIUM** |
| **Mobile App** | Production Android Build Config | **BROKEN** | `mobile_app/android/app/build.gradle.kts` | Package name is `com.example.mobile_app`, release builds signed with debug keys, missing `google-services.json` | Configure release keystore, update bundle ID, add `google-services.json` | **HIGH** |
| **Testing** | Backend Pytest Execution | **BROKEN** | `backend/tests/test_e2e_integration.py` | Test functions named `run_e2e_test()` instead of `test_...()`; `pytest` collects 0 tests | Rename functions to `test_e2e_integration()` so Pytest discovers them | **HIGH** |
| **Testing** | Flutter Mobile Tests | **DONE** | `mobile_app/test/` | 41 unit and widget tests passing across avatars, verification, and profile guards | Add end-to-end integration tests with mock HTTP client | **MEDIUM** |
| **Testing** | Smart Contract Tests | **MISSING** | `blockchain/` directory | No Hardhat test suite (`test/` folder is absent) | Create Hardhat tests validating contract event emission and access control | **MEDIUM** |

---

## 3. Database Audit

### Current Database Architecture

* **Primary Engine:** SQLAlchemy 2.0 (`backend/database.py`) targeting PostgreSQL 16.
* **Current Runtime:** Falls back automatically to local SQLite database `backend/honeychain.db` (344 KB) because no PostgreSQL server is running.
* **Secondary Shadow Engine:** Prisma 5.11 (`backend/prisma/schema.prisma`) configured with SQLite `backend/prisma/dev.db`.
* **Discrepancy:** The Node.js service and Python FastAPI service use isolated databases with differing table schemas and incompatible naming schemes.

### Models & Schema Inventory (`backend/models.py`)

1. `User` (`users`): Primary key UUID, composite unique constraint on `(email, role)`. Indexes on `role`. Contains contact, facility, and role metadata.
2. `Profile` (`profiles`): 1-to-1 extension of `User`. Foreign key `user_id` with `CASCADE` delete. Tracks government ID, KYC status, and verification stamps.
3. `Hive` (`hives`): Foreign key `user_id` (`User.id`). Unique `hive_code`, unique `device_id`. Indexes on `user_id`, `device_id`, `hive_code`.
4. `HiveTelemetry` (`hive_telemetry`): Time-series sensor log. Foreign key `hive_id`. Stores temperature, humidity, weight, acoustics, battery, signal strength. Indexes on `hive_id`, `device_id`, `recorded_at`.
5. `HiveAIAnalysis` (`hive_ai_analysis`): Diagnostic outputs from Isolation Forest and Risk Engine. Foreign key `hive_id`. Stores risk level, anomaly score, and JSON diagnostic breakdowns.
6. `HiveAlert` (`hive_alerts`): Real-time threshold alerts. Foreign key `hive_id`. Tracks severity, parameter deltas, and acknowledgment state.
7. `CollectionCentre` (`collection_centres`): Geographic hub with latitude/longitude coordinates and FSSAI license.
8. `Harvest` (`harvests`): Raw honey extraction log. Foreign key `harvester_id`, nullable foreign key `hive_id`.
9. `CollectionRequest` (`collection_requests`): Inter-role workflow request. Tracks status transitions: `PENDING` → `ACCEPTED` → `SENT_TO_LAB` → `SENT_TO_PACKAGING` → `COMPLETED`.
10. `CollectionBatch` (`collection_batches`): Central supply chain entity with unique `batch_id` (e.g., `HC-BATCH-2026-XXXXXX`).
11. `ProcessingBatch` (`processing_batches`): Centrifugal filtration and cold extraction record. Foreign key `processor_id`.
12. `Lab` (`labs`): NABL/FSSAI accredited testing laboratory entity. Foreign key `user_id`.
13. `LabRequest` (`lab_requests`): Formal sample submission linked to `batch_id`.
14. `LabReport` (`lab_reports`): Certified physicochemical testing results (moisture, HMF, diastase, pollen morphology).
15. `PackagingFacility` (`packaging_facilities`): Bottling and cleanroom facility record.
16. `PackagingBatch` (`packaging_batches`): Final packaging record with unit count, container type, seal type, and QR code URL.
17. `BlockchainRecord` (`blockchain_records`): Off-chain audit mirror of EVM transactions. Stores `batch_id`, `event_type`, `data_hash`, `tx_hash`, `block_number`, `status`.
18. `QRCode` (`qr_codes`): Unique mapping of `batch_id` to public verification URL and base64 PNG data URI.
19. `Notification` (`notifications`): In-app push notifications for beekeepers and supply chain actors.
20. `OTPVerification` (`otp_verifications`): Temporary OTP verification records with expiration timestamps.

### Production Cloud Database Requirements

To make the existing SQLAlchemy architecture production-ready without disrupting the application logic:

1. **Target Technology:** Managed PostgreSQL 16 (AWS RDS PostgreSQL, Google Cloud SQL, or Neon/Supabase).
2. **Environment Variables:**
   ```env
   DATABASE_URL="postgresql://honeychain_user:<STRONG_PASSWORD>@<CLOUD_HOST>:5432/honeychain?sslmode=require"
   DB_POOL_SIZE=10
   DB_MAX_OVERFLOW=20
   DB_POOL_TIMEOUT=30
   ```
3. **Connection Pooling in `database.py`:**
   ```python
   engine = create_engine(
       DATABASE_URL,
       pool_size=int(os.getenv("DB_POOL_SIZE", 10)),
       max_overflow=int(os.getenv("DB_MAX_OVERFLOW", 20)),
       pool_pre_ping=True,
       pool_recycle=1800,
   )
   ```
4. **Migrations:** Remove runtime `ALTER TABLE` logic from `database.py` and initialize standard Alembic:
   ```bash
   alembic init alembic
   alembic revision --autogenerate -m "Initial production schema"
   alembic upgrade head
   ```
5. **Backups:** Configure automated daily cloud snapshots with 7-day point-in-time recovery (PITR).

---

## 4. Real Data Audit (Mock, Dummy & Placeholder Findings)

Every occurrence of hardcoded or dummy values identified across the repository:

### 1. Hardcoded Blockchain Private Key
* **File:** `backend/services/blockchain_service.py` (line 22) & `backend/src/index.ts` (line 47)
* **Current Behavior:** Falls back to Hardhat Account 0 test key: `'0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80'`.
* **Why Dummy:** Well-known public test private key; insecure for production.
* **Real Source:** Dedicated production custodial wallet stored in AWS Secrets Manager or secure `.env`.
* **Required Change:** Enforce `os.environ["BLOCKCHAIN_PRIVATE_KEY"]` with no default fallback.

### 2. Auto-Accepting Dummy OTP Verification
* **File:** `backend/main.py` (line 1815)
* **Current Behavior:** `if otp_val in ("123456", "000000") or len(otp_val) == 6:` returns success for any 6-digit number.
* **Why Dummy:** Mock bypass created for UI testing without cellular SMS delivery.
* **Real Source:** Verifying submitted code against database record in `OTPVerification` table with expiration check, or calling live 2Factor/MSG91 DLT gateway.
* **Required Change:** Query `OTPVerification` table matching `phone` and `otp_code` where `expires_at > datetime.utcnow()`.

### 3. Automatic Dummy User Creation on Login
* **File:** `backend/main.py` (lines 437–448)
* **Current Behavior:** If user does not exist during login, automatically generates a new user named `"User"` with email `@honeychain.io`.
* **Why Dummy:** Allowed demo users to type anything into the login box without registering first.
* **Real Source:** Strict authentication lookup against registered credentials in the database.
* **Required Change:** Raise HTTP 401 Unauthorized if user credentials do not match database records.

### 4. Dummy Default Harvester in Hive Creation
* **File:** `backend/main.py` (lines 587–592)
* **Current Behavior:** If `x-user-id` header is missing, automatically assigns hive to first harvester found or creates `"Registered Harvester"`.
* **Why Dummy:** Prevents API crash when frontend fails to supply user ID header.
* **Real Source:** Authenticated user identity extracted directly from verified JWT token.
* **Required Change:** Require `Depends(get_current_active_user)` and assign `hive.user_id = current_user.id`.

### 5. Static Default Hardware Device ID
* **File:** `backend/main.py` (line 693)
* **Current Behavior:** Ingesting telemetry without device ID falls back to `"SIH_HIVE_MVP_01"`.
* **Why Dummy:** Static fallback used in early hackathon prototypes.
* **Real Source:** Unique hardware serial number provisioned on physical ESP32 efuse / MAC address.
* **Required Change:** Reject telemetry payloads missing valid `device_id` with HTTP 422 Unprocessable Entity.

### 6. Localhost QR Verification URLs
* **File:** `backend/services/qr_service.py` (line 12)
* **Current Behavior:** Encodes `http://127.0.0.1:8000/verify/{batch_id}` into QR codes.
* **Why Dummy:** Local development default. Fails when scanned on external mobile devices.
* **Real Source:** Public domain URL configured via environment variable (e.g., `https://verify.honeychain.io`).
* **Required Change:** Load `PUBLIC_APP_URL` from environment and validate it starts with `https://`.

---

## 5. Authentication & User System Audit

### Findings

1. **Password Hashing:**
   * In `backend/main.py:406`, passwords are encrypted using unsalted SHA-256:  
     `hashlib.sha256(payload.password.encode("utf-8")).hexdigest()`.
   * **Vulnerability:** Highly susceptible to rainbow table and brute-force attacks.
   * **Required Fix:** Adopt `bcrypt` or `passlib[bcrypt]` with minimum work factor of 12.
2. **Login Parameter Mismatch:**
   * Flutter's `AuthController` sends `{ "emailOrPhone": identifier, "password": pass, "role": roleStr }`.
   * FastAPI's `LoginRequest` expects `{ "email": Optional[str], "phone": Optional[str], "password": Optional[str] }`.
   * As a result, `payload.email` and `payload.phone` evaluate to `None`, triggering the automatic dummy user creation fallback.
3. **Session & Token Handling:**
   * Login returns `"token": f"jwt-{uuid.uuid4().hex}"`. This is a random string, not a signed JSON Web Token.
   * No backend endpoint implements token verification (`Authorization: Bearer <token>`). Endpoints either read an optional `x-user-id` header or pick the first database record.
4. **Google Authentication:**
   * `POST /api/auth/google` accepts arbitrary client-provided `email` and `photoUrl` without verifying the Google OAuth2 `idToken` with Google's servers.
   * **Vulnerability:** Any malicious user can impersonate any email address simply by sending that email in the JSON body.
5. **Role Isolation:**
   * The database enforces composite uniqueness `(email, role)`, allowing the same email address to hold separate accounts across Harvester, Collection, Lab, and Packaging roles. However, because FastAPI lacks `/api/auth/accounts` and `/api/auth/switch-role`, role switching fails on mobile.

---

## 6. Role-Based System Audit

| Role | Intended Workflow | Implementation Status | Issues Identified |
| :--- | :--- | :--- | :--- |
| **Harvester** | Complete profile → Register Hive → Ingest Telemetry → Monitor Health → Request Collection | **PARTIAL** | Profile completion not enforced on backend; auto-assigns hives to first harvester if unauthenticated; direct raw telemetry not saved by MQTT worker. |
| **Collection & Processing** | Accept Harvester Request → Receive Physical Honey → Cold Extraction → Create Processing Batch → Discover Nearest Lab → Request Lab Test | **PARTIAL** | Backend allows request acceptance without checking if collector profile is verified. Batch processing logic works correctly and updates `ProcessingBatch`. |
| **Analytical Lab** | View Incoming Lab Requests → Enter Physicochemical Test Parameters (Moisture, HMF, Diastase, Pollen) → Approve/Reject Batch → Record On-Chain | **DONE (Off-Chain)** | Lab report generation and parameter validation working; records to `LabReport` and computes blockchain tamper-evident hash; requires live EVM node for on-chain block mining. |
| **Packaging** | View Approved Batches → Bottle & Seal (Jars, Volume) → Generate Final Cryptographic QR → Complete Batch Lifecycle | **DONE (Off-Chain)** | Final packaging records created; QR generated as Base64 data URI; batch status set to `COMPLETED`; verification URL points to `127.0.0.1` instead of public domain. |
| **Consumer** | Scan Bottle QR → View Full Provenance Timeline (Hive to Bottle) + Lab Certifications + Blockchain Hashes | **DONE** | Public endpoint `/verify/{batch_id}` renders responsive web view with full timeline, lab metrics, and blockchain transaction verification. |

---

## 7. Profile Completion Logic Audit

### Requirement
The following actions must be strictly prohibited until the user's role-specific profile and verification are complete:
1. Add Hive
2. Send Collection Request
3. Accept Processing Request
4. Find Nearest Lab
5. Send Lab Request
6. Send Packaging
7. Generate Final Product QR

### Audit Results

* **Flutter Frontend:** **PASSED.**  
  `mobile_app/lib/core/utils/profile_guard.dart` contains complete guard checks:
  * `checkHarvesterVerificationOrPrompt`
  * `checkCollectorVerificationOrPrompt`
  * `checkLabVerificationOrPrompt`
  * `checkPackagingVerificationOrPrompt`  
  When incomplete, displays an unignorable dialog with the required message: *"Complete your profile and required details before continuing with this role action."*
* **FastAPI Backend:** **FAILED.**  
  In `backend/main.py`, endpoints `/api/hives`, `/api/requests`, `/api/harvests`, `/api/processing`, `/api/lab-reports`, and `/api/packaging` execute without inspecting user verification state or checking whether mandatory profile fields are present.
* **Express Backend (`backend/src/`):** **PARTIALLY PASSED.**  
  Contains `isUserProfileComplete` and `isHarvesterFullyVerified` in `profileService.ts`, returning HTTP 403 Forbidden with `PROFILE_INCOMPLETE_RESPONSE`. However, lines 29, 133, 150, 167, and 184 bypass checks if `process.env.NODE_ENV !== 'production'`.

---

## 8. Hive System & The `POST /api/hives → 403` Root Cause

### The Root Cause of `POST /api/hives → 403`

When running against the Express backend or when production profile validation is active, `POST /api/hives` inspects:
1. `isUserProfileComplete(user)`: Checks for full name, valid email, and verified phone number.
2. `isHarvesterFullyVerified(user.harvesterVerification)`: Checks whether:
   * Government ID is `"Verified"`
   * Mobile OTP is `"Verified"`
   * Registration is `"Verified"`
   * Blockchain verification ID exists

If a newly registered beekeeper attempts to add a hive before completing these three verification steps in the app, the backend rejects the request with HTTP 403:
```json
{
  "success": false,
  "code": "HARVESTER_VERIFICATION_REQUIRED",
  "message": "Complete profile verification to add hives and start harvesting activities."
}
```

### Why It Appeared "Fixed" or "Inconsistent"
In `backend/main.py`, this verification check was omitted entirely and replaced with fallback dummy harvester creation. Thus, calling FastAPI on port 8000 succeeded, while calling Express on port 3000 returned 403.

### Required Architecture Fix
The FastAPI backend must implement a unified dependency `get_verified_current_user`:
```python
def require_verified_harvester(current_user: User = Depends(get_current_user)):
    if not current_user.is_verified:
        raise HTTPException(
            status_code=403,
            detail={
                "code": "HARVESTER_VERIFICATION_REQUIRED",
                "message": "Complete profile verification to add hives and start harvesting activities."
            }
        )
    return current_user
```

---

## 9. IoT, MQTT & AI/ML Integration Audit

### Intended Integration
```
ESP32 Node (Raw Telemetry)
       ↓ MQTT Topic: "honeychain/hive/telemetry"
Mosquitto Broker (1883)
       ↓
AI/ML Processor (`ai_ml/mqtt/mqtt_processor.py`)
       ↓ Feature Extraction & Anomaly Scoring
       ↓ MQTT Topic: "honeychain/hive/processed"
Backend Consumer (`backend/services/mqtt_consumer.py`)
       ↓
PostgreSQL Persistence + WebSocket Broadcast
```

### Critical Integration Issues Identified

1. **Raw Telemetry Discarded:** In `backend/services/mqtt_consumer.py:58-59`, messages received on `honeychain/hive/telemetry` are discarded with `logger.debug()`. If the AI/ML service is stopped, raw telemetry is never stored in the database.
2. **Cold Start Data Requirement in AI Service:** In `ai_ml/mqtt/mqtt_processor.py:186-194`, `feature_builder.build_latest_features(device_id)` requires 145 historical readings (24 hours at 10-minute intervals). Until 145 readings accumulate in memory, the AI processor logs `"Waiting for enough history before running ML inference"` and exits without publishing to `honeychain/hive/processed`.
3. **Loss of In-Memory State on Restart:** `FeatureBuilder` in `ai_ml/src/feature_builder.py` stores hive history in an in-memory `collections.deque`. If the AI/ML process restarts, all accumulated temporal history is lost, resetting the 24-hour waiting window.
4. **WebSocket Threading Collision:** In `backend/main.py:183`, `on_mqtt_data` invokes `asyncio.run(manager.broadcast(data))` on incoming MQTT packets. Because MQTT runs in a secondary background thread, calling `asyncio.run()` creates a detached event loop that cannot safely communicate with FastAPI's main event loop WebSockets, raising `RuntimeError`.

---

## 10. Blockchain Audit

### Smart Contract: `HoneyChainProvenance.sol`
* **Solidity Version:** `^0.8.20`
* **Storage Entities:**
  * `batchEvents`: Mapping from `batchId` to array of `BatchEvent` structs (`eventType`, `actorId`, `dataHash`, `previousEventHash`, `timestamp`).
  * `harvesterVerifications`: Mapping from `verificationId` to `HarvesterVerificationRecord` structs (`harvesterId`, `recordHash`, `status`, `timestamp`).
* **Access Control:** `onlyOwner` modifier protects write operations (`recordEvent`, `recordHarvesterVerification`).

### Hardhat & Network Configuration
* **Configuration:** `blockchain/hardhat.config.js` only configures `localhost: "http://127.0.0.1:8545"`.
* **Missing Testnet:** No Polygon Amoy testnet configuration exists. No RPC URL, Chain ID (80002), or gas parameters are configured.
* **Deploy Script Bug:** `blockchain/scripts/deploy.js` line 7 contains broken JavaScript:  
  `console.log(HoneyChainProvenance deployed to );`  
  Running `npx hardhat run scripts/deploy.js` crashes immediately.

### On-Chain vs. Off-Chain Data Separation
* **On-Chain (Blockchain):**
  * SHA-256 Cryptographic Hash of the supply chain event payload (`dataHash`).
  * Batch ID and Event Type.
  * Actor ID and Block Timestamp.
* **Off-Chain (PostgreSQL):**
  * Full sensor time-series data.
  * Detailed lab reports (moisture %, HMF, diastase, pollen origin).
  * Personal identifiable information (names, phone numbers, apiary addresses).
  * Transaction hash and block number references linking off-chain records to the ledger.
* **Offline Tamper-Evident Fallback:** When the blockchain node is offline, `BlockchainService.record_batch_event()` computes the SHA-256 hash, stores it in `blockchain_records` with status `PENDING`, and logs it for reconciliation.

---

## 11. Complete Traceability Chain Audit

Every final honey jar can be traced through the following unified relationship chain:

```
PackagingBatch (`packaging_batches.batch_id`)
      ↓ (batch_id)
LabReport (`lab_reports.batch_id`)
      ↓ (batch_id)
ProcessingBatch (`processing_batches.batch_id`)
      ↓ (batch_id)
CollectionRequest (`collection_requests.batch_id`)
      ↓ (hive_id, harvester_id)
Harvest (`harvests.id`)
      ↓ (hive_id)
Hive (`hives.id`)
      ↓ (device_id)
HiveTelemetry (`hive_telemetry.hive_id`)
      ↓ (telemetry_id)
HiveAIAnalysis (`hive_ai_analysis.hive_id`)
      ↓ (batch_id)
BlockchainRecord (`blockchain_records.batch_id`)
```

### Traceability Integrity Finding
The database models correctly share `batch_id` (format: `HC-BATCH-2026-XXXXXX`) across collection, processing, lab testing, packaging, and blockchain records. However, in `backend/main.py:1225` (`POST /api/harvests`), the harvest record creation does not enforce that the provided `hive_id` belongs to the authenticated harvester.

---

## 12. Final QR System Audit

1. **Generation:** Invoked during final packaging via `backend/services/qr_service.py:generate_qr_data_uri(batch_id)`. Produces both a verification URL and an RFC 2397 Base64 PNG Data URI (`data:image/png;base64,...`).
2. **Persistence:** Saved to the `qr_codes` table and embedded into `PackagingBatch.qr_code_url`.
3. **Verification Endpoint:**
   * `GET /verify/{batch_id}`: If accessed by a web browser (`Accept: text/html`), renders a responsive HTML provenance certificate displaying apiary coordinates, harvest date, cold extraction parameters, full lab chemical breakdown, blockchain transaction hashes, and tamper-evident status.
   * `GET /api/verify/{batch_id}`: Returns complete JSON payload for Flutter mobile client inspection.
4. **Issue:** Base URL defaults to `http://127.0.0.1:8000`. Scanning on a smartphone fails because `127.0.0.1` loops back to the phone itself. Must be parameterized via `PUBLIC_APP_URL`.

---

## 13. API Audit

| Endpoint | Method | Auth Required | Role | Database Model | Frontend Used? | Working? | Known Problems |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `/api/health` | GET | None | Any | `User` check | Yes | **Yes** | None |
| `/api/auth/register` | POST | None | Any | `User` | Yes | **Partial** | Uses plain unsalted SHA-256 password hash |
| `/api/auth/login` | POST | None | Any | `User` | Yes | **Broken** | Ignores password, mismatched `emailOrPhone` parameter |
| `/api/auth/google` | POST | None | Any | `User` | Yes | **Broken** | Does not verify Google OAuth ID token with Google |
| `/api/auth/accounts` | GET | Token | Any | `User` | Yes | **Missing** | Called by `user_controller.dart`; returns 404 in FastAPI |
| `/api/auth/switch-role`| POST | Token | Any | `User` | Yes | **Missing** | Called by `user_controller.dart`; returns 404 in FastAPI |
| `/api/auth/forgot-password`| POST | None | Any | None | Yes | **Missing** | FastAPI names it `/api/auth/reset-password`; Flutter calls `/forgot-password` |
| `/api/profile` | GET | Optional | Any | `User`, `Profile` | Yes | **Partial** | Falls back to first user in database if ID omitted |
| `/api/profile` | PUT | Optional | Any | `User` | Yes | **Partial** | No ownership check; any user can modify any profile |
| `/api/hives` | GET | Optional | Harvester | `Hive` | Yes | **Yes** | Filters by `userId` or `harvesterId` query parameter |
| `/api/hives` | POST | Header | Harvester | `Hive` | Yes | **Broken** | No profile completion check; auto-creates dummy harvester |
| `/api/hives/{hive_id}` | GET | None | Harvester | `Hive` | Yes | **Yes** | Look up by UUID or `hive_code` |
| `/api/telemetry/ingest` | POST | None | IoT Node | `HiveTelemetry` | Yes | **Yes** | Ingests sensor reading and creates threshold alerts |
| `/api/telemetry/live/{id}` | GET | None | Harvester | `HiveTelemetry` | Yes | **Yes** | Returns latest 30 telemetry points |
| `/api/telemetry/alerts` | GET | None | Harvester | `HiveAlert` | Yes | **Yes** | Returns active alerts |
| `/api/centers/nearest` | GET | None | Harvester | `CollectionCentre` | Yes | **Yes** | Calculates Haversine distance from GPS coordinates |
| `/api/requests` | GET | None | Any | `CollectionRequest` | Yes | **Yes** | Returns list of requests |
| `/api/requests` | POST | None | Harvester | `CollectionRequest` | Yes | **Partial** | No profile completion validation |
| `/api/requests/{id}/accept` | PATCH | None | Collector | `CollectionRequest` | Yes | **Partial** | Records blockchain event off-chain; no role check |
| `/api/requests/{id}/send-next` | POST | None | Collector/Lab | `LabRequest` | Yes | **Partial** | Advances stage; no authorization check |
| `/api/harvests` | POST | None | Harvester | `Harvest`, `Batch` | Yes | **Partial** | Creates harvest without verifying hive ownership |
| `/api/processing` | POST | None | Collector | `ProcessingBatch` | Yes | **Yes** | Records extraction method and moisture |
| `/api/lab-reports` | POST | None | Lab | `LabReport` | Yes | **Yes** | Validates physicochemical standards |
| `/api/packaging` | POST | None | Packager | `PackagingBatch` | Yes | **Yes** | Generates QR code and marks batch completed |
| `/api/verify/{batch_id}` | GET | None | Public | All Models | Yes | **Yes** | Returns full JSON provenance tree |
| `/verify/{batch_id}` | GET | None | Public | All Models | Yes | **Yes** | Serves dynamic HTML verification certificate |
| `/ws/telemetry` | WS | None | Mobile | None | Yes | **Broken** | Background thread broadcast raises `RuntimeError` |

---

## 14. Flutter Mobile App Audit

### Findings
1. **Dependency Health:** `pubspec.yaml` dependencies resolved cleanly. All 41 unit and widget tests in `mobile_app/test/` passed.
2. **Hardcoded IP & Localhost References:**
   * `mobile_app/lib/core/constants/app_constants.dart:12`:  
     `static const String backendBaseUrl = 'http://127.0.0.1:8000';`
   * Android emulator fallback resolves `http://10.0.2.2:8000`.
   * For physical device testing and production deployment, these must be replaced by environment build variables:
     ```dart
     static const String backendBaseUrl = String.fromEnvironment(
       'BACKEND_URL',
       defaultValue: 'https://api.honeychain.io',
     );
     ```
3. **Dead Endpoints in Controllers:**
   * `mobile_app/lib/features/profile/controllers/user_controller.dart`:
     * Line 467 calls `$_baseUrl/api/auth/accounts` (returns 404 on FastAPI).
     * Line 488 calls `$_baseUrl/api/auth/switch-role` (returns 404 on FastAPI).
   * `mobile_app/lib/features/authentication/auth_controller.dart`:
     * Line 283 calls `$_baseUrl/api/auth/forgot-password` (FastAPI route is `/api/auth/reset-password`).
4. **Android Build Configuration (`mobile_app/android/app/build.gradle.kts`):**
   * Package ID is set to `com.example.mobile_app`. Needs production domain (e.g., `io.honeychain.app`).
   * `buildTypes.release` is configured with debug signing keys (`signingConfigs.getByName("debug")`).
   * Missing `google-services.json` in `mobile_app/android/app/`.

---

## 15. Production Configuration Audit

### Hardcoded Secret & Host Violations
* `backend/services/blockchain_service.py:22`: Hardcoded Hardhat private key.
* `backend/services/blockchain_service.py:23`: Hardcoded local contract address `0x5FbDB2315678afecb367f032d93F642f64180aa3`.
* `backend/src/index.ts:47`: Duplicate hardcoded private key and contract address.
* `mobile_app/lib/firebase_options.dart`: Client API keys present (standard for Firebase client SDKs, but domain restrictions must be enforced in Google Cloud Console).
* `mosquitto/mosquitto.conf`: `allow_anonymous true` with no authentication or TLS encryption.

---

## 16. Cloud Deployment Audit

### 1. Backend Service (FastAPI)
* **Hosting:** Containerized on AWS ECS / Google Cloud Run / DigitalOcean App Platform.
* **Runtime:** Python 3.11/3.12 with Uvicorn ASGI server behind an Nginx reverse proxy.
* **Process Command:** `uvicorn backend.main:app --host 0.0.0.0 --port 8000 --workers 4`.
* **Required Environment Variables:**
  * `DATABASE_URL`: Cloud PostgreSQL connection string with SSL mode required.
  * `JWT_SECRET_KEY`: High-entropy 256-bit secret.
  * `BLOCKCHAIN_PROVIDER_URL`: Polygon Amoy RPC URL.
  * `BLOCKCHAIN_PRIVATE_KEY`: Custodial contract admin wallet private key.
  * `CONTRACT_ADDRESS`: Deployed `HoneyChainProvenance` contract address on Amoy.
  * `MQTT_HOST`, `MQTT_PORT`, `MQTT_USER`, `MQTT_PASSWORD`.
  * `PUBLIC_APP_URL`: Canonical public web URL (e.g., `https://api.honeychain.io`).

### 2. Relational Database (PostgreSQL)
* Managed PostgreSQL 16 on Cloud SQL / AWS RDS.
* Connection pooling enabled with `pgbouncer` or SQLAlchemy pool pre-ping.
* Automated daily backups with WAL archiving.

### 3. Blockchain Deployment (Polygon Amoy Testnet)
* Contract deployed via Hardhat to Polygon Amoy (Chain ID: 80002).
* Verified on Amoy Polygonscan with published ABI.

### 4. MQTT Broker
* Cloud-hosted Mosquitto or EMQX broker.
* Port 8883 enabled with TLS/SSL encryption.
* Mutual username/password or token-based client authentication.

### 5. AI/ML Inference Service
* Can run as a containerized worker (`python -m ai_ml.mqtt.mqtt_processor`) sharing the cloud MQTT broker.
* Model joblib file mounted via persistent volume or baked into the container image.

---

## 17. Security Audit

| Severity | Category | Vulnerability Description | Mitigation |
| :--- | :--- | :--- | :--- |
| **CRITICAL** | Authentication | Password verification completely absent in FastAPI `/api/auth/login`. Any request logs in. | Verify submitted password against stored `bcrypt` hash. |
| **CRITICAL** | Authorization | No token or identity validation on supply chain mutation endpoints (IDOR vulnerability). | Implement FastAPI `Depends(get_current_user)` on all write routes. |
| **CRITICAL** | Key Management | Hardhat private key committed to repository in source code. | Move private keys to secure environment variables or AWS Secrets Manager. |
| **HIGH** | Cryptography | Passwords hashed using unsalted single-iteration SHA-256. | Migrate to `bcrypt` or `argon2`. |
| **HIGH** | Authentication | Google login does not verify token signature with Google OAuth servers. | Verify ID tokens using `google-auth` / Firebase Admin SDK. |
| **HIGH** | Network Security | MQTT broker permits unauthenticated anonymous read/write access. | Require username/password and TLS on port 8883. |
| **MEDIUM** | Network Security | CORS configured with `allow_origins=["*"]` and `allow_credentials=True`. | Restrict CORS allowed origins to production web domains. |
| **MEDIUM** | Rate Limiting | No rate limiting on OTP generation or login routes. | Implement Redis-backed `slowapi` rate limiter on auth routes. |

---

## 18. Testing Audit

* **Backend Test Discovery Bug:** In `backend/tests/test_e2e_integration.py` and `backend/tests/test_scenario_49.py`, the test entry points were defined as `def run_e2e_test()` and `def run_section_49_scenario()`. Running `pytest` discovered 0 tests and exited with an error code. Renaming them to `test_e2e_integration()` and `test_scenario_49()` enables automated CI/CD execution.
* **End-to-End Test Verification:** Executed directly via Python, the full supply chain pipeline (Health Check → AI Feature Builder → Isolation Forest → Risk Engine → MQTT Payload → DB Telemetry → Harvester Request → Collection Processing → Lab Certification → Packaging → Public QR Verification) executed and passed all assertions against the local SQLite fallback.
* **Flutter Test Suite:** Executed `flutter test`. All 41 unit and widget tests passed across avatar rendering, profile guards, harvester verification models, and hive calculations.
* **Smart Contracts:** Zero test files exist in the `blockchain/` directory.

---

## 19. Master Bug & Error Inventory

1. `backend/main.py:437`: Missing `emailOrPhone` handling in `LoginRequest`.
2. `backend/main.py:433`: Absence of password hash verification during login.
3. `backend/main.py:183`: `asyncio.run()` in MQTT thread breaks WebSocket broadcast.
4. `backend/main.py:1815`: OTP check accepts any 6-digit number (`len(otp_val) == 6`).
5. `blockchain/scripts/deploy.js:7`: Syntax error: unquoted text in `console.log()`.
6. `backend/tests/test_e2e_integration.py:28`: Non-standard test function name causes Pytest failure.
7. `backend/tests/test_scenario_49.py:35`: Non-standard test function name causes Pytest failure.
8. `backend/services/blockchain_service.py:75`: Missing HTTP timeout on `Web3.HTTPProvider` causes 20-second API hangs when node is offline.
9. `mobile_app/lib/features/profile/controllers/user_controller.dart:467`: Calls non-existent `/api/auth/accounts`.
10. `mobile_app/lib/features/profile/controllers/user_controller.dart:488`: Calls non-existent `/api/auth/switch-role`.
11. `mobile_app/lib/features/authentication/auth_controller.dart:283`: Calls `/api/auth/forgot-password` (FastAPI route is `/reset-password`).
12. `mobile_app/android/app/build.gradle.kts:19`: Package ID is placeholder `com.example.mobile_app`.
13. `mobile_app/android/app/build.gradle.kts:36`: Release builds use debug keystore.
14. `mobile_app/android/app/`: Missing `google-services.json`.

---

## 20. Documentation Audit

* **Present:**
  * Root `README.md`: High-level project overview and architecture.
  * `backend/README.md`: Route architecture and technology specifications.
  * `ai_ml/README.md`: Comprehensive model documentation, dataset statistics, and MQTT contracts.
  * `iot/README.md`: Pinout reference, hardware wiring table, and telemetry JSON schema.
  * `mosquitto/README.md`: Broker port mapping and CLI test commands.
  * `blockchain/README.md`: Hardhat instructions and contract method descriptions.
* **Missing:**
  * Cloud deployment guide (AWS/GCP/DigitalOcean).
  * Production environment variables guide (`.env.production`).
  * Android release signing and APK compilation guide.
  * Database migration runbook.

---

## 21. Git & Repository Audit

* **Active Branch:** `feature/development`
* **Untracked Artifacts in Git Ignore:** `.gitignore` correctly ignores `*.db`, `node_modules/`, `.dart_tool/`, `dist/`, and build outputs.
* **Clean Working Directory:** No dirty untracked code modifications.

---

## 22. Dependency Audit

* **Flutter (`pubspec.yaml`):** Dependencies resolved without conflicts. 24 packages have newer minor versions available, but existing versions are fully compatible.
* **Backend (`REQUIREMENT.txt`):** Dependencies (`fastapi`, `uvicorn`, `sqlalchemy`, `pydantic`, `web3`, `paho-mqtt`, `qrcode`) are compatible with Python 3.11 and 3.13.
* **Blockchain (`package.json`):** Hardhat and ethers versions are compatible with Node.js LTS.

---

## 23. Project Health Summary

### A. Overall Health Summary

* **Overall Implementation:** **68%**
* **Backend:** **65%** (FastAPI works, but lacks proper auth validation, profile gates, and role switching)
* **Flutter Mobile App:** **85%** (UI, navigation, and controllers complete; needs updated base URL and missing endpoints)
* **Database:** **60%** (SQLAlchemy schema complete; needs cloud PostgreSQL and Alembic migrations)
* **Blockchain:** **55%** (Smart contract complete; deploy script broken; needs Polygon Amoy configuration)
* **AI/ML:** **90%** (Trained model, feature builder, and risk engine complete; needs warm-up fallback)
* **IoT / MQTT:** **40%** (Specs complete, MQTT broker config ready; firmware source files missing)
* **Authentication:** **35%** (UI complete; backend login accepts anything, fake JWTs, no route protection)
* **QR Verification:** **80%** (QR generation and web/API verification working; needs public domain config)
* **Deployment:** **25%** (Docker compose for Postgres/Mosquitto exists; missing cloud deployment manifests)
* **Testing:** **60%** (Flutter 41/41 pass, E2E test passes; Pytest discovery broken; missing contract tests)
* **Security:** **30%** (Critical password, token, and IDOR vulnerabilities must be addressed before production)
* **Documentation:** **75%** (Module READMEs complete; missing cloud and release guides)

### B. Completed Work
* Complete 5-stage supply chain data model in SQLAlchemy.
* Isolation Forest anomaly detection and temporal risk scoring engine in Python.
* Full Flutter UI across Harvester, Collector, Lab, Packaging, and Public Consumer roles.
* Public QR verification web page with responsive HTML and cryptographic timeline.
* Off-chain cryptographic hash generation linking supply chain events.
* 41 unit/widget tests in Flutter passing.

### C. Partially Completed Work
* **Blockchain Integration:** Smart contract written, but deploy script broken and not deployed to Polygon Amoy testnet.
* **MQTT Ingestion:** Listens to processed topic, but ignores direct raw telemetry and has WebSocket threading issues.
* **Database Setup:** Schema defined, but running on local SQLite fallback without Alembic migrations.

### D. Broken Features
* **FastAPI Login (`/api/auth/login`):** Mismatched payload parsing and lack of password validation.
* **WebSocket Live Stream (`/ws/telemetry`):** Cross-thread `asyncio.run()` crash.
* **Blockchain Deploy Script (`blockchain/scripts/deploy.js`):** Syntax error prevents contract deployment.
* **Backend Pytest Discovery:** Test runner exits with 0 tests collected due to naming convention.
* **Web3 Synchronous Call Timeout:** 20-second timeout freezes API when blockchain node is offline.

### E. Completely Missing Features
* Cloud PostgreSQL database instance and Alembic migrations.
* Server-side profile completion authorization gate on FastAPI routes.
* Signed JWT token authentication middleware.
* `/api/auth/accounts` and `/api/auth/switch-role` endpoints in FastAPI.
* Physical ESP32 Arduino/PlatformIO C++ sketch in `iot/`.
* Android release keystore and `google-services.json`.

---

## 24. Remaining Work Master Checklist

### 🔴 CRITICAL — Must Fix Before Any Demo or Deployment
- [ ] **Fix FastAPI Authentication (`backend/main.py`):**
  - [ ] Parse `emailOrPhone` correctly in `LoginRequest`.
  - [ ] Implement `bcrypt` password verification against `User.password_hash`.
  - [ ] Issue authentic signed HMAC-SHA256 JWT tokens with expiration.
  - [ ] Implement FastAPI `get_current_user` dependency and protect all mutation routes.
- [ ] **Enforce Backend Profile Completion Gate:**
  - [ ] Add `require_verified_harvester`, `require_verified_collector`, `require_verified_lab`, and `require_verified_packager` dependencies.
  - [ ] Return HTTP 403 Forbidden with `"Complete your profile before continuing"` if incomplete.
- [ ] **Port Missing Auth Endpoints to FastAPI:**
  - [ ] Implement `GET /api/auth/accounts` (list role accounts for an email).
  - [ ] Implement `POST /api/auth/switch-role` (switch active role context).
  - [ ] Add alias for `POST /api/auth/forgot-password`.
- [ ] **Fix Deploy Script Syntax Error:**
  - [ ] Fix string quoting in `blockchain/scripts/deploy.js:7`.
- [ ] **Fix Pytest Function Naming:**
  - [ ] Rename `run_e2e_test()` to `test_e2e_integration()` in `backend/tests/test_e2e_integration.py`.
  - [ ] Rename `run_section_49_scenario()` to `test_section_49_scenario()` in `backend/tests/test_scenario_49.py`.

### 🟠 HIGH — Required Before Final Demonstration
- [ ] **Fix WebSocket Broadcasting:**
  - [ ] Replace `asyncio.run()` in `main.py` MQTT callback with `asyncio.run_coroutine_threadsafe()`.
- [ ] **Fix Raw MQTT Telemetry Persistence:**
  - [ ] Update `backend/services/mqtt_consumer.py` to persist sensor packets directly to `HiveTelemetry` on `TELEMETRY_TOPIC`.
- [ ] **Deploy Smart Contract to Polygon Amoy:**
  - [ ] Add Polygon Amoy RPC and testnet private key to `blockchain/hardhat.config.js`.
  - [ ] Deploy `HoneyChainProvenance.sol` to Amoy and update `CONTRACT_ADDRESS` in `.env`.
- [ ] **Fix Web3 Call Timeout:**
  - [ ] Configure `Web3.HTTPProvider(RPC_URL, request_kwargs={"timeout": 2})` to prevent 20-second API freezes.
- [ ] **Provide ESP32 Firmware Sketch:**
  - [ ] Create `iot/firmware/esp32_honeychain.ino` with DHT22, HX711, INMP441, and WiFi/MQTT drivers.
- [ ] **Parameterize Public Verification URL:**
  - [ ] Replace `http://127.0.0.1:8000` with `PUBLIC_APP_URL` in `qr_service.py`.

### 🟡 MEDIUM — Required for Production Quality
- [ ] **Cloud PostgreSQL Migration:**
  - [ ] Launch managed PostgreSQL instance on cloud provider.
  - [ ] Initialize Alembic migrations and apply schema.
  - [ ] Seed initial collection centres, accredited labs, and packaging units.
- [ ] **Android Production Preparation:**
  - [ ] Change package name from `com.example.mobile_app` to `io.honeychain.app`.
  - [ ] Add `google-services.json` to `mobile_app/android/app/`.
  - [ ] Generate release keystore and update `signingConfigs` in `build.gradle.kts`.
- [ ] **Secure MQTT Broker:**
  - [ ] Configure Mosquitto with password file and TLS listener on port 8883.
- [ ] **Smart Contract Automated Tests:**
  - [ ] Create `blockchain/test/HoneyChainProvenance.test.js` covering batch events and access control.

### 🟢 LOW — Code Quality & Operational Improvements
- [ ] Retire or consolidate the unused Express/Prisma subsystem in `backend/src/` to prevent confusion.
- [ ] Upgrade outdated Flutter dependencies flagged during `pub outdated`.
- [ ] Add Redis caching for `/api/centers/nearest` Haversine queries.

---

## 25. Recommended Development Order

To execute the integration and production deployment systematically without regressions:

1. **Step 1: Fix Backend Authentication & Token Security**
   * Update `backend/main.py` to accept `emailOrPhone`, hash passwords with `bcrypt`, issue real JWTs, and protect API routes.
2. **Step 2: Implement Server-Side Profile Completion Gates**
   * Add middleware/dependencies in `backend/main.py` blocking unverified actions across Harvester, Collector, Lab, and Packaging.
3. **Step 3: Port Missing Account Endpoints to FastAPI**
   * Add `/api/auth/accounts`, `/api/auth/switch-role`, and `/api/auth/forgot-password` to `main.py`.
4. **Step 4: Fix Telemetry Ingestion & WebSocket Threading**
   * Store raw telemetry packets in `mqtt_consumer.py` and fix cross-thread WebSocket broadcasting.
5. **Step 5: Fix Blockchain Deployment & Timeouts**
   * Correct `deploy.js`, add Polygon Amoy to `hardhat.config.js`, deploy the contract, and add short HTTP timeouts to Web3 calls.
6. **Step 6: Fix Pytest Suite**
   * Rename test functions so `pytest` executes and passes in CI/CD.
7. **Step 7: Provide ESP32 Firmware**
   * Add reference C++ firmware sketch in `iot/` matching the MQTT JSON schema.
8. **Step 8: Configure Production Database & Alembic**
   * Connect to PostgreSQL 16, run Alembic migrations, and verify connection pooling.
9. **Step 9: Configure Flutter Mobile App for Production**
   * Add build-time `BACKEND_URL`, update Android package ID, add release signing, and place `google-services.json`.
10. **Step 10: End-to-End Verification & Demo Preparation**
    * Execute end-to-end supply chain progression on Polygon Amoy testnet and verify public QR certificate scanning on mobile.
