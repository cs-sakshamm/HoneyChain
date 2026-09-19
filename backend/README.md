# HoneyChain — Backend Services & API Architecture

The HoneyChain backend is the integration and business-logic core of the platform: it ingests IoT telemetry over MQTT, persists AI/ML hive analyses, coordinates the harvest → collection → processing → lab → packaging supply chain, anchors provenance to an EVM smart contract, and exposes REST + WebSocket APIs consumed by the Flutter app.

---

## 1. Technology Stack

* **Python FastAPI** (`main.py`): REST API, WebSocket endpoints, lifespan-managed background services.
* **SQLAlchemy 2.x** (`database.py`, `models.py`): ORM layer. **Supabase PostgreSQL is the authoritative database** (required `DATABASE_URL`). SQLite is used *only* when explicitly requested for tests (`ENV=test` or `DEV_OFFLINE_SQLITE=true`) — there is **no silent fallback**.
* **Paho-MQTT 2.x** (`services/mqtt_consumer.py`): background consumer for telemetry and AI/ML processed messages, started/stopped with the FastAPI lifespan.
* **Web3.py 8.x** (`services/blockchain_service.py`): EVM contract client for `HoneyChainProvenance.sol`.
* **qrcode + Pillow** (`services/qr_service.py`): QR tag generation as base64 data URIs.
* **python-jose / passlib**: JWT issuing/verification and password hashing.
* **Node.js** (blockchain toolchain only): the Hardhat TypeScript toolchain lives in `blockchain/` — there is **no** Express/Prisma service inside `backend/` (a superseded Node implementation was archived and removed from the repository; it remains recoverable at the `legacy-express-backend-archive` tag).

---

## 2. Directory Structure

```text
backend/
├── main.py                     # FastAPI app: routes, auth, WebSocket, lifespan wiring
├── database.py                 # DATABASE_URL loading, engine/session factory, health check
├── db_base.py                  # Shared SQLAlchemy declarative Base (single registry)
├── models.py                   # ORM models: users → hives → telemetry → AI → supply chain → QR
├── alembic/                    # Migrations (same DATABASE_URL as the app)
├── services/
│   ├── blockchain_service.py   # Web3 contract connector + transaction recorder
│   ├── mqtt_consumer.py        # MQTT consumer: validation, persistence, WS bridge
│   └── qr_service.py           # QR generation utilities
├── tests/                      # Pytest suite (18 tests)
├── .env.example                # Template configuration (names only, no secrets)
└── README.md
```

---

## 3. Data Model (`models.py`)

1. **`User`** — role-based identity (`HARVESTER`, `COLLECTOR`, `LAB_TESTER`, `PACKAGING_MANAGER`, `PUBLIC_CONSUMER`), email/password + Firebase identity, OTP state.
2. **`Hive`** — physical hive; unique `device_id` (e.g. `SIH_HIVE_MVP_01`) → `hive_code` → owner `user_id`.
3. **`HiveTelemetry`** — time-series readings (`temperature_c`, `humidity_pct`, `weight_kg`, `acoustics_hz`, `battery_v`, `wifi_rssi_dbm`, `timestamp`); indexed by device + timestamp; idempotent on `(hive_id, device_id, timestamp)`.
4. **`HiveAIAnalysis`** — stored AI/ML output: `risk_level` (LOW/MEDIUM/HIGH), `status` (HEALTHY/ATTENTION/ALERT), `anomaly_detected`, `anomaly_score`, per-parameter breakdowns, analysis JSON.
5. **`HiveAlert`** — alerts produced by the AI/ML pipeline with acknowledgment tracking.
6. **`CollectionCentre` / `CollectionRequest` / `CollectionBatch`** — collection stage.
7. **`ProcessingBatch`** — filtration/heating parameters and yield.
8. **`Lab` / `LabRequest` / `LabReport`** — lab metrics (moisture, pollen, HMF, purity, C4 adulteration), grade, certificate hash.
9. **`PackagingBatch`** — container sizes, unit counts, QR assignment.
10. **`QRCode`** — `qr_hash` → entity mapping + base64 image.
11. **`BlockchainRecord`** — on-chain tx hash / block number / payload hash audit trail.

---

## 4. API Surface (`main.py`)

All application routes are mounted under both `/api/...` (canonical, used by the Flutter app) and legacy un-prefixed aliases where noted. JWT auth via `Authorization: Bearer`; ownership is enforced (a user cannot read another user's hive by swapping IDs).

### Core & Health
* `GET /` — API root
* `GET /api/health` (alias `/health`) — DB engine type/latency, MQTT, blockchain status

### Authentication
* `POST /api/auth/register` — register (email/password; roles)
* `POST /api/auth/login` — JWT login
* `POST /api/auth/google` — Firebase Google sign-in exchange
* `GET /api/auth/accounts` — saved accounts
* `POST /api/auth/switch-role`
* `POST /api/auth/forgot-password`, `POST /api/auth/reset-password`
* `POST /api/verification/send-otp`, `POST /api/verification/verify-otp`
* `POST /api/verification/{role}/{step}` (and sub-step variants) — role verification workflow
* `GET /api/verification/{role}/status/{user_id}`
* `GET /api/profile`, `PUT /api/profile`

### Hives & Telemetry (ownership-enforced)
* `GET /api/hives`, `POST /api/hives`, `GET /api/hives/{id}`, `DELETE /api/hives/{id}`
* `GET /api/hives/code/generate`, `GET /api/hives/unique-code`
* `GET /api/hives/{id}/telemetry/latest` — latest snapshot + AI status + AI readiness (`requiredReadings` ≈ 145)
* `GET /api/hives/{id}/telemetry?limit=` — history (newest first)
* `GET /api/hives/{id}/status` — AI status bundle
* `GET /api/telemetry/live/{id}` — legacy live view (auth required)
* `GET /api/telemetry/alerts`, `POST /api/telemetry/alerts/{id}/acknowledge`
* `POST /api/telemetry/ingest` — manual ingestion (validation enforced; no fabricated defaults)

### Supply Chain
* `POST /api/harvests` — record harvest session
* `GET /api/requests`, `POST /api/requests` — collection requests
* `PATCH /api/requests/{id}/accept|reject|status`, `POST /api/requests/{id}/send-next`
* `GET /api/centers/nearest`, `GET /api/requests/nearest-centers`
* `POST /api/processing` — processing parameters
* `POST /api/lab-reports` — lab metrics + certificate hash
* `POST /api/packaging` — packaging batches + QR generation

### Verification & Traceability (public)
* `GET /api/verify/{batch_id}` (alias `/verify/{batch_id}`) — full provenance payload
* `GET /api/traceability/{batch_id}`
* `GET /api/verify/harvester/{verification_id}`

### WebSockets (JWT-authenticated)
* `WS /ws`, `WS /ws/telemetry`, `WS /api/telemetry/live` — server pushes telemetry/AI/alert events as they are persisted from MQTT; unauthenticated connections are rejected (close code 4401).

---

## 5. MQTT Integration

Flow (the `ai_ml/` processor is external and untouched by this layer):

```text
ESP32/simulator → honeychain/hive/telemetry → (existing AI/ML processor)
              → honeychain/hive/processed → backend MQTT consumer
              → validation → PostgreSQL → WebSocket broadcast → Flutter
```

* Consumes both topics; AI/ML `processed` messages are handled on a priority queue so insights are never stuck behind a raw-telemetry burst.
* Strict payload validation: `device_id`, valid epoch `timestamp`, and all four sensor channels (`temperature_c`, `humidity_pct`, `weight_kg`, `acoustics_hz`) must exist and be numeric — malformed messages are logged and rejected, never stored with fabricated values.
* Idempotent persistence keyed on `(hive_id, device_id, timestamp)` — MQTT QoS-1 redelivery cannot create duplicates.
* Automatic reconnect; MQTT failures never take FastAPI down.

---

## 6. Environment Variables (names only — never commit values)

```env
# Server
PORT=8000
ENVIRONMENT=development

# Database (Supabase PostgreSQL — authoritative; URL-encode the password)
DATABASE_URL=postgresql://<user>:<password>@<host>:5432/postgres
# Test-only offline mode (otherwise unused):
# DEV_OFFLINE_SQLITE=true

# MQTT
MQTT_HOST=localhost
MQTT_PORT=1883
MQTT_USERNAME=            # optional
MQTT_PASSWORD=            # optional
MQTT_INPUT_TOPIC=honeychain/hive/telemetry
MQTT_OUTPUT_TOPIC=honeychain/hive/processed

# Blockchain
BLOCKCHAIN_PROVIDER_URL=http://127.0.0.1:8545
BLOCKCHAIN_CHAIN_ID=31337
CONTRACT_ADDRESS=<deployed address>
BLOCKCHAIN_PRIVATE_KEY=<funded key for the target network>

# Auth
JWT_SECRET_KEY=<random secret>
JWT_ALGORITHM=HS256
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=60

# External providers (optional)
GOOGLE_CLIENT_ID=
AADHAAR_PROVIDER=sandbox
OTP_PROVIDER=sandbox

# Public verification portal used inside generated QR payloads
PUBLIC_APP_URL=https://<public-host>
```

---

## 7. Running

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate            # Windows  (source .venv/bin/activate on Unix)
pip install -r REQUIREMENT.txt

uvicorn backend.main:app --host 0.0.0.0 --port 8000 --reload
```

Docs at `http://localhost:8000/docs` (Swagger) and `/redoc`. On startup the app runs Alembic-compatible schema init (`init_db`), connects to PostgreSQL (fail-fast with a sanitized error if unreachable), and starts the MQTT consumer.

### Migrations

```bash
cd backend
python -m alembic upgrade head    # same DATABASE_URL as the app
```

---

## 8. Testing

```bash
# from the repository root
backend\.venv\Scripts\python.exe -m pytest backend/tests -q     # 18 tests
```

Covers: end-to-end supply chain, telemetry persistence + idempotency, malformed-payload rejection, REST latest/history/status, cross-user authorization (403), WebSocket auth, and startup behavior. Tests default to an isolated SQLite database (`conftest.py`); run against PostgreSQL by exporting `DATABASE_URL` and clearing `DEV_OFFLINE_SQLITE`.

The blockchain EVM integration of the backend service is exercised from the blockchain layer: `cd blockchain && npm run test:backend-evm`.

---

## 9. Security Notes

* Passwords hashed (passlib); JWTs signed server-side; role checks on all state-changing routes.
* Hive-scoped endpoints enforce ownership — ID-swapping returns 403/404, not data.
* WebSocket connections require a valid token.
* Database URLs and driver errors are sanitized before logging; secrets live only in `backend/.env` (gitignored).
* No automatic SQLite fallback in production paths — a broken PostgreSQL connection is surfaced, not masked.
