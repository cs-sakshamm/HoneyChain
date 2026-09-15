# HoneyChain — Backend Services & API Architecture

The HoneyChain backend serves as the core integration and business logic engine of the HoneyChain ecosystem. It ingests IoT telemetry, interfaces with AI anomaly detection, coordinates supply chain transactions across five role stages, anchors cryptographic provenance to EVM smart contracts, and exposes RESTful and real-time WebSocket APIs to the Flutter mobile application and public consumers.

---

## 1. Technologies & Frameworks

* **Python FastAPI (`main.py`):** High-performance asynchronous REST and WebSocket API server.
* **SQLAlchemy 2.0 (`database.py`, `models.py`):** Enterprise ORM managing relational schemas across SQLite (default development) and PostgreSQL 16 (production).
* **Paho-MQTT 2.0 (`services/mqtt_consumer.py`):** Background worker subscribing to IoT telemetry and AI/ML processed insights.
* **Web3.py 6.x (`services/blockchain_service.py`):** Client for deploying, querying, and recording batch events to EVM smart contracts (`HoneyChainProvenance.sol`).
* **QRCode & Pillow (`services/qr_service.py`):** Base64 Data URI generator for batch and bottle traceability QR tags.
* **Node.js Express & Prisma (`src/`, `prisma/`):** Dedicated microservice module for Aadhaar eKYC, SMS OTP gateway routing, and TypeScript workflow validations.

---

## 2. Directory Structure

```text
backend/
├── database.py                 # SQLAlchemy database engine, session factory, & table initializer
├── honeychain.db               # SQLite development database (auto-generated)
├── main.py                     # Central FastAPI application with all route definitions & lifespan hooks
├── models.py                   # SQLAlchemy ORM models covering users, hives, batches, labs, & QR
├── services/
│   ├── blockchain_service.py   # Web3 EVM contract connector and transaction recorder
│   ├── mqtt_consumer.py        # Background MQTT thread listening to telemetry & processed topics
│   └── qr_service.py           # QR code generation utilities returning base64 data URIs
├── prisma/
│   ├── schema.prisma           # Prisma relational schema for Node service
│   ├── dev.db                  # Prisma SQLite database
│   └── seed.ts                 # Database seeding script for demo data
├── src/                        # Express / TypeScript KYC & verification service
│   ├── index.ts                # Express application entrypoint
│   ├── routes/                 # Express route handlers (auth, hive, telemetry, verification, workflow)
│   └── services/               # KYC providers (sandbox, signzy, hyperverge, digio) & SMS gateways
├── tests/
│   ├── test_e2e_integration.py # Full Pytest suite testing end-to-end supply chain progression
│   └── test_scenario_49.py     # Targeted integration test for hive alert & batch scenarios
├── .env.example                # Template configuration for environment variables
├── .gitignore                  # Git ignore rules tailored for Python, Node, and Prisma
├── README.md                   # Backend documentation (this file)
└── REQUIREMENT.txt             # Complete Python and Node dependency specifications
```

---

## 3. Database Schema & Models (`models.py`)

The backend models map directly to real-world honey supply chain entities:

1. **`User` & `Profile`:** Role-based identity (`HARVESTER`, `COLLECTOR`, `LAB_TESTER`, `PACKAGING_MANAGER`, `PUBLIC_CONSUMER`) with Aadhaar number, phone verification, and apiary coordinates.
2. **`Hive`:** Represents a physical beehive linked to a unique `device_id` (e.g., `SIH_HIVE_MVP_01`) and `hive_code`.
3. **`HiveTelemetry`:** Time-series telemetry readings:
   * `weight_kg`, `temperature_c`, `humidity_pct`, `acoustics_hz`, `battery_v`, `wifi_rssi_dbm`, `timestamp`.
4. **`HiveAIAnalysis`:** AI-evaluated diagnostic metrics:
   * `risk_level` (`LOW`, `MEDIUM`, `HIGH`), `status` (`HEALTHY`, `ATTENTION`, `ALERT`), `anomaly_detected` (bool), `anomaly_score` (float), breakdown statuses for temperature, humidity, weight trend, and acoustics.
5. **`HiveAlert`:** Actionable alerts (`SEVERITY_LOW`, `SEVERITY_MEDIUM`, `SEVERITY_HIGH`, `SEVERITY_CRITICAL`) dispatched to beekeepers with resolution tracking.
6. **`CollectionCentre` & `CollectionRequest`:** Geo-located hubs and collection requests created by harvesters.
7. **`CollectionBatch`:** Aggregated raw honey batches created by collectors upon physical receipt.
8. **`ProcessingBatch`:** Refined batches documenting filtration type (e.g., Ultrafiltration, Gravity), heating temperature (°C), and net yield.
9. **`Lab` & `LabRequest`:** Testing facilities and official sample submission records.
10. **`LabReport`:** Lab results documenting moisture %, pollen count, HMF (mg/kg), purity score (0–100), adulteration flag, quality grade (Grade A/B/C), and cryptographic certificate hash.
11. **`PackagingBatch`:** Retail packaging records linking container size (e.g., 250g, 500g, 1000g), unit count, serial numbers, and assigned QR codes.
12. **`QRCode`:** Mapping of `qr_hash` to physical entities with downloadable base64 image data.
13. **`BlockchainRecord`:** Audit trail indexing on-chain transaction hashes, block numbers, and payload hashes.

---

## 4. API Endpoints Architecture (`main.py`)

### Core & Health
* `GET /`: API root status.
* `GET /health`: Detailed service health check (DB connectivity, MQTT status, Web3 status).
* `GET /stats`: Aggregated system statistics (total hives, batches, lab tests, packaged jars).

### Authentication & Profiles
* `POST /auth/register`: Register user with specific role.
* `POST /auth/login`: Authenticate and receive session tokens.
* `GET /auth/me`: Fetch currently authenticated user context.
* `POST /auth/otp/send`: Dispatch 6-digit SMS OTP (sandbox / MSG91 / 2Factor).
* `POST /auth/otp/verify`: Validate submitted OTP.
* `GET /profile`: Retrieve harvester/collector profile.
* `PUT /profile`: Update profile information.
* `POST /profile/kyc`: Submit Aadhaar / government ID verification.

### Hives & Telemetry
* `GET /hives`: List hives belonging to the authenticated harvester.
* `POST /hives`: Register a new hive and link an ESP32 `device_id`.
* `GET /hives/{hive_id}`: Retrieve detailed hive metrics and recent telemetry.
* `GET /hives/{hive_id}/telemetry`: Fetch paginated historical sensor readings.
* `GET /hives/{hive_id}/analysis`: Fetch latest AI risk analysis and diagnostic breakdown.
* `GET /hives/{hive_id}/alerts`: Fetch active alerts for a hive.
* `POST /hives/{hive_id}/alerts/{alert_id}/resolve`: Mark an alert as resolved.

### Real-Time WebSockets
* `WebSocket /ws/telemetry`: Bi-directional WebSocket connection. Broadcasts real-time telemetry packets and critical alerts directly to mobile dashboards as soon as MQTT messages arrive.

### Supply Chain Management
* `GET /collection/centers`: Query nearby registered collection hubs with GPS coordinates.
* `POST /collection/requests`: Harvester submits raw honey batch for collection.
* `PATCH /collection/requests/{id}/status`: Collector accepts, schedules, or rejects request.
* `POST /collection/batches`: Collector creates an aggregated collection batch and triggers on-chain anchor.
* `POST /processing/batches`: Record processing parameters (filtration grade, temperature).
* `POST /lab/requests`: Submit honey sample for accredited laboratory analysis.
* `POST /lab/reports`: Lab technician records chemical metrics, grade, and commits certificate hash to blockchain.
* `POST /packaging/batches`: Packaging manager logs packaged jars and generates traceability QR codes.

### Public Verification
* `GET /verify/{code}`: Public endpoint returning full provenance history, lab metrics, and blockchain transaction proof for a batch or QR code.
* `GET /qr/{code}/image`: Generates and serves a PNG QR code image directly for printing.

---

## 5. Subsystem Integrations

### IoT & MQTT Consumer (`mqtt_consumer.py`)
* Connects to Mosquitto MQTT broker on startup via FastAPI `lifespan`.
* Subscribes to:
  * `honeychain/hive/telemetry`: Direct sensor stream from ESP32 nodes.
  * `honeychain/hive/processed`: AI/ML analyzed stream containing risk scores and feature evaluations.
* Performs database insertion into `HiveTelemetry` and `HiveAIAnalysis`.
* Automatically identifies abnormal readings and creates `HiveAlert` entries.
* Broadcasts payload over `/ws/telemetry` to active mobile clients.

### Blockchain Client (`blockchain_service.py`)
* Connects via Web3 to the configured Ethereum RPC (`BLOCKCHAIN_RPC_URL`).
* Interacts with `HoneyChainProvenance.sol`:
  * `recordEvent(batchId, eventType, actorId, dataHash, previousEventHash)`
  * `recordHarvesterVerification(verificationId, harvesterId, recordHash, status)`
  * `getEvents(batchId)`
* Automatically computes SHA-256 payload digests ensuring cryptographic proof of origin.

---

## 6. Environment Variables Reference

Create `.env` in `backend/` using the following verified keys:

```env
# Server Configuration
PORT=8000
ENVIRONMENT=development

# Relational Database
# SQLite (development default):
DATABASE_URL="sqlite:///./honeychain.db"
# PostgreSQL (production via docker-compose):
# DATABASE_URL="postgresql://postgres:postgres@localhost:5432/honeychain"

# MQTT Broker Configuration
MQTT_HOST="localhost"
MQTT_PORT=1883
MQTT_INPUT_TOPIC="honeychain/hive/telemetry"
MQTT_OUTPUT_TOPIC="honeychain/hive/processed"

# Blockchain Node & Smart Contract
BLOCKCHAIN_RPC_URL="http://127.0.0.1:8545"
CONTRACT_ADDRESS="0x5FbDB2315678afecb367f032d93F642f64180aa3"
BLOCKCHAIN_PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

# KYC & SMS Provider Configuration
AADHAAR_PROVIDER="sandbox"
OTP_PROVIDER="sandbox"
```

---

## 7. Running the Backend

### Running the Python FastAPI Backend

```bash
# 1. Activate Python virtual environment
.\.venv\Scripts\Activate.ps1  # Windows
# source .venv/bin/activate    # Linux/macOS

# 2. Install dependencies
pip install -r backend/REQUIREMENT.txt

# 3. Start server with uvicorn
uvicorn backend.main:app --host 0.0.0.0 --port 8000 --reload
```

Interactive API documentation will be available at:
* Swagger UI: [http://localhost:8000/docs](http://localhost:8000/docs)
* ReDoc: [http://localhost:8000/redoc](http://localhost:8000/redoc)

### Running the Node.js Express / Prisma Service (Optional)

```bash
cd backend
npm install
npx prisma generate
npx prisma db push
npm run dev
```

---

## 8. Testing

Run automated end-to-end integration tests using `pytest`:

```bash
# Run all backend integration tests
pytest backend/tests/test_e2e_integration.py -v

# Run targeted scenario tests
pytest backend/tests/test_scenario_49.py -v
```
