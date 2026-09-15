# HoneyChain — Decentralized End-to-End Honey Traceability & Quality Assurance Platform

HoneyChain is an enterprise-grade honey provenance, IoT telemetry monitoring, AI-driven anomaly detection, and decentralized supply chain verification platform. It tracks honey from raw apiary harvest to consumer packaging, cryptographically sealing every milestone onto an EVM-compatible blockchain and exposing public batch verification via QR codes.

---

## 1. Project Overview

HoneyChain guarantees honey purity, combats adulteration, and provides transparent provenance across the entire honey lifecycle. The platform directly integrates:

* **Harvester & Hive Management:** Beekeepers register apiaries, configure hives, log inspection records, and track colony health in real time.
* **IoT Telemetry & Edge Sensing:** ESP32 microcontrollers deployed inside beehives stream ambient temperature, relative humidity, total hive weight, and acoustic frequency.
* **Mosquitto MQTT Event Bus:** High-throughput, lightweight messaging broker routing raw hardware telemetry to the AI engine and FastAPI backend.
* **AI/ML Anomaly Detection:** Multivariate time-series analysis (Isolation Forest baseline + LSTM Autoencoder research model) running on live sensor feeds to flag colony collapse, swarming, moisture spikes, or thermal distress.
* **Collection & Aggregation:** Field collectors inspect raw honey, accept/reject harvester collection requests, and consolidate harvested yields into trackable collection batches.
* **Processing & Filtration:** Facilities record honey filtration grades, heating temperatures, processing methods, and yield weights.
* **Laboratory Testing & Certification:** Certified labs perform comprehensive tests (moisture %, pollen count, HMF content, purity index, C4 sugar adulteration tests) and issue signed quality certificates.
* **Packaging & QR Generation:** Packaging units seal honey into serialized consumer containers, generating unique cryptographic QR codes for public verification.
* **Blockchain Provenance:** Smart contracts (`HoneyChainProvenance.sol`) immutably store SHA-256 state hashes, timestamps, and actor identities for every physical event.
* **Public QR Verification:** Consumers scan product QR codes or query batch numbers via mobile/web to inspect the unalterable journey from flower to jar.

### Real Data Flow

HoneyChain enforces real, verified data progression throughout the entire pipeline:

```text
Real User (Harvester/KYC)
  ↓
Real Hive (Registered Hardware Device)
  ↓
Real Harvest (Weight & Moisture Recorded)
  ↓
Real Collection Request (Geo-tagged to nearest Hub)
  ↓
Real Processing (Filtration & Dehumidification)
  ↓
Real Lab Report (Purity, Pollen & HMF Metrics)
  ↓
Real Certification (Quality Grade & Lab Sign-off)
  ↓
Real Packaging (Serialized Consumer Jars)
  ↓
Real QR Code (Cryptographic Traceability URI)
  ↓
Real Blockchain Verification (Immutable Transaction Proof)
```

---

## 2. System Architecture

HoneyChain adopts a layered, microservice-oriented architecture connecting edge IoT devices, intelligent processing nodes, persistent relational storage, EVM smart contracts, and client-facing interfaces:

```text
┌─────────────────────────────────────────────────────────────┐
│                       Flutter Mobile App                    │
│   (Harvester, Collector, Lab Tester, Packaging, Consumer)   │
└──────────────┬───────────────────────────────▲──────────────┘
               │ HTTP REST                     │ WebSockets
               ▼                               │ (Live Alerts)
┌──────────────────────────────────────────────┴──────────────┐
│                    FastAPI Central Backend                  │
│       (Auth, Hives, Supply Chain, QR, Blockchain Sync)      │
└───────┬──────────────────────┬──────────────────────┬───────┘
        │                      │                      │
        ▼                      ▼                      ▼
┌──────────────┐      ┌─────────────────┐    ┌────────────────┐
│  PostgreSQL  │      │   Mosquitto     │    │  EVM Contract  │
│  / SQLite DB │      │   MQTT Broker   │    │  (Provenance)  │
└──────────────┘      └────────┬────────┘    └────────────────┘
                               ▲
               honeychain/     │   honeychain/
               hive/processed  │   hive/telemetry
                               │
                      ┌────────┴────────┐
                      │  AI/ML Engine   │
                      │(IsolationForest)│
                      └────────▲────────┘
                               │
                      ┌────────┴────────┐
                      │   IoT / ESP32   │
                      │  (Sensor Nodes) │
                      └─────────────────┘
```

### Data Flow Breakdown

1. **Edge Acquisition:** ESP32 sensors sample temperature, humidity, hive weight, and acoustics every 10 minutes (or 1 second in test simulation) and publish JSON to topic `honeychain/hive/telemetry`.
2. **AI Telemetry Processing:** The AI/ML engine (`ai_ml.mqtt.mqtt_processor`) consumes raw telemetry, extracts temporal window features (1h deltas, 6h rolling averages, 24h weight deltas), evaluates anomaly scores using an Isolation Forest, applies reference boundary rules, and publishes structured diagnostics to `honeychain/hive/processed`.
3. **Backend Persistence & Broadcast:** The FastAPI MQTT consumer (`backend.services.mqtt_consumer`) receives the processed payload, commits readings to `hive_telemetry`, records AI diagnostics into `hive_ai_analysis`, triggers `hive_alerts` for high-risk conditions, and broadcasts live JSON packets over WebSockets (`/ws/telemetry`) to connected Flutter apps.
4. **Supply Chain Progression:** Each role (Harvester -> Collector -> Lab -> Packaging) updates the state machine through authenticated REST endpoints in `backend/main.py`.
5. **Blockchain Anchoring:** During critical state changes (batch collection, lab certification, packaging release), the backend service (`backend.services.blockchain_service`) hashes the batch metadata (SHA-256) and calls `recordEvent` on the `HoneyChainProvenance` smart contract.
6. **Consumer Verification:** When a QR code is scanned, the backend queries the database for the complete batch ancestry and verifies the on-chain cryptographic hash against the ledger.

---

## 3. End-to-End Workflow

```text
1. Harvester Registration & KYC
   └── Harvester signs up, undergoes Aadhaar / phone OTP verification, and sets up apiary location.

2. Hive Configuration & IoT Ingestion
   └── Hardware device ID (e.g., SIH_HIVE_MVP_01) is linked to the hive; continuous telemetry streams.

3. Honey Harvest Session
   └── Harvester logs harvest date, floral origin (e.g., Mustard, Acacia, Multifloral), and yield weight (kg).

4. Collection Request Creation
   └── Harvester requests batch pickup; nearest collection centres are located with geo-coordinates.

5. Collection & Weight Verification
   └── Collector inspects raw honey, verifies gross weight, accepts batch, and records collection event on-chain.

6. Processing & Refining
   └── Processing center filters impurities, tests moisture, and records processing yield and batch ID.

7. Laboratory Quality Assurance
   └── Lab technician tests moisture %, pollen count, HMF (hydroxymethylfurfural), and C4 sugars.

8. Lab Certification
   └── Certified lab report issues Grade A/B/C rating; signed certificate hash is committed to blockchain.

9. Product Packaging
   └── Honey is poured into serialized jars; net weights and packaging dates are logged.

10. QR Generation & Labelling
    └── Unique QR code linking to public verification portal is generated and attached to each container.

11. Public Verification
    └── Retail consumers scan QR code or enter batch code to inspect immutable supply chain history.
```

---

## 4. Repository Structure

```text
HoneyChain/
├── backend/                  # Central FastAPI backend, SQLAlchemy models, WebSockets, & Node KYC services
│   ├── database.py           # SQLite / PostgreSQL engine & session factory
│   ├── main.py               # Central FastAPI REST & WebSocket server
│   ├── models.py             # SQLAlchemy ORM schemas for all supply chain stages
│   ├── services/             # Blockchain Web3 client, MQTT consumer, & QR code generator
│   ├── prisma/               # Node Prisma ORM schema and seed scripts
│   ├── src/                  # Express TypeScript routes and KYC/SMS provider integrations
│   ├── tests/                # Pytest end-to-end integration and scenario tests
│   ├── .env.example          # Template environment configuration
│   ├── README.md             # Backend detailed developer documentation
│   └── REQUIREMENT.txt       # Verified Python & Node backend dependencies
│
├── mobile_app/               # Cross-platform Flutter client application
│   ├── lib/
│   │   ├── core/             # Themes, widgets, controllers, constants, & localization
│   │   └── features/         # Authentication, Hives, Collection, Lab, Packaging, & Verification
│   ├── assets/images/        # App branding and graphic assets
│   ├── pubspec.yaml          # Flutter dependencies and asset registrations
│   ├── README.md             # Mobile application setup, role flows, and build guide
│   └── REQUIREMENT.txt       # Verified Flutter SDK, Dart, & package requirements
│
├── blockchain/               # EVM Smart Contracts & Hardhat development environment
│   ├── contracts/            # HoneyChainProvenance.sol Solidity contract
│   ├── scripts/              # Contract compilation & deployment automation
│   ├── hardhat.config.js     # Hardhat network configuration
│   ├── package.json          # Hardhat, Ethers.js, and Ganache dependencies
│   ├── README.md             # Smart contract specifications, deployment, & tests
│   └── REQUIREMENT.txt       # Verified Node & Solidity dependencies
│
├── iot/                      # Hive edge IoT sensing firmware specifications & contracts
│   ├── README.md             # ESP32 sensor wiring, telemetry contract, & MQTT guide
│   └── REQUIREMENT.txt       # Microcontroller hardware & C++/Arduino library requirements
│
├── mosquitto/                # MQTT message broker configuration
│   ├── mosquitto.conf        # Listener and authentication settings
│   ├── README.md             # Mosquitto broker operations and debugging instructions
│   └── REQUIREMENT.txt       # Mosquitto server and CLI requirements
│
├── shared/                   # Cross-module types, schemas, and state definitions
│   ├── README.md             # Universal entity IDs, JSON contracts, and state machine docs
│   └── REQUIREMENT.txt       # Shared schema validation requirements
│
├── docs/                     # System architecture blueprints & technical documentation
│   ├── README.md             # Documentation index and architecture specifications
│   └── REQUIREMENT.txt       # Documentation toolchain requirements
│
├── ai_ml/                    # [READ-ONLY] Isolation Forest & LSTM anomaly detection engine
│   ├── data/                 # Synthetic Indian hive telemetry datasets
│   ├── models/               # Pretrained Isolation Forest joblib & threshold configurations
│   ├── mqtt/                 # Live MQTT stream processor subscribing to telemetry
│   ├── src/                  # Feature builder, anomaly detector, & risk engine
│   └── README.md             # AI subsystem operations (untouched)
│
├── docker-compose.yml        # PostgreSQL 16 & Mosquitto container orchestration
├── .gitignore                # Global Git ignore rules protecting source code
├── README.md                 # Root HoneyChain platform overview & setup guide (this file)
└── REQUIREMENT.txt           # Ecosystem-wide runtime requirements
```

> [!IMPORTANT]
> **AI/ML Folder Integrity:** The `ai_ml/` folder is strictly read-only and maintained independently. No changes, edits, refactoring, or automatic formatting may be performed inside `ai_ml/`.

---

## 5. Environment Variables Reference

Copy `.env.example` to `.env` in the `backend/` directory before starting services:

| Variable | Default Value / Format | Purpose |
| :--- | :--- | :--- |
| `DATABASE_URL` | `sqlite:///./honeychain.db` | Database connection string (`postgresql://user:pass@localhost:5432/honeychain` for Postgres) |
| `PORT` | `8000` | Port for the central FastAPI server |
| `MQTT_HOST` | `localhost` | MQTT Broker hostname (Mosquitto) |
| `MQTT_PORT` | `1883` | MQTT Broker port |
| `MQTT_INPUT_TOPIC` | `honeychain/hive/telemetry` | Raw ESP32 telemetry topic |
| `MQTT_OUTPUT_TOPIC` | `honeychain/hive/processed` | AI/ML processed telemetry topic |
| `BLOCKCHAIN_RPC_URL` | `http://127.0.0.1:8545` | EVM JSON-RPC endpoint (Ganache or Hardhat node) |
| `CONTRACT_ADDRESS` | `0x...` | Deployed address of `HoneyChainProvenance.sol` |
| `BLOCKCHAIN_PRIVATE_KEY` | `0x...` | Private key for signing blockchain provenance transactions |
| `AADHAAR_PROVIDER` | `sandbox` | KYC verification provider (`sandbox`, `signzy`, `hyperverge`, `digio`) |
| `OTP_PROVIDER` | `sandbox` | SMS OTP provider (`sandbox`, `2factor`, `msg91`) |

*Never commit `.env` or production private keys to version control.*

---

## 6. Setup & Installation

### Prerequisites

Ensure the following tools are installed:
* Python 3.10 or 3.11
* Node.js >= 18.0.0 & npm >= 9.0.0
* Flutter SDK >= 3.0.0 < 4.0.0
* Docker & Docker Compose

### 1. Start Infrastructure (PostgreSQL & Mosquitto)

Launch the message broker and database containers:

```bash
docker-compose up -d
```

Verify Mosquitto is active on port 1883 and PostgreSQL is healthy on port 5432.

### 2. Setup Blockchain Node & Deploy Contract

In a dedicated terminal:

```bash
cd blockchain
npm install
npx hardhat node
```

In a second terminal, deploy the smart contract:

```bash
cd blockchain
node scripts/deploy.js
```

Note the deployed contract address and export it to your backend `.env` (`CONTRACT_ADDRESS=0x...`).

### 3. Setup & Run Central FastAPI Backend

In a dedicated terminal:

```bash
# Create and activate Python virtual environment
python -m venv .venv
# On Windows PowerShell:
.\.venv\Scripts\Activate.ps1
# On Linux/macOS:
# source .venv/bin/activate

# Install backend dependencies
pip install -r backend/REQUIREMENT.txt

# Start FastAPI server with live reload
uvicorn backend.main:app --host 0.0.0.0 --port 8000 --reload
```

FastAPI interactive documentation will be available at:
* Swagger UI: [http://localhost:8000/docs](http://localhost:8000/docs)
* OpenAPI JSON: [http://localhost:8000/openapi.json](http://localhost:8000/openapi.json)

### 4. Run the AI Telemetry Processor

In a dedicated terminal:

```bash
# Using the same Python virtual environment
python -m ai_ml.mqtt.mqtt_processor
```

The processor will subscribe to `honeychain/hive/telemetry` and begin publishing evaluated insights to `honeychain/hive/processed`.

### 5. Simulate Telemetry (Optional for Development)

If physical ESP32 hardware is not yet connected, run the automated simulator:

```bash
python -m ai_ml.tests.mqtt_simulator
```

### 6. Run the Flutter Mobile Application

In a dedicated terminal:

```bash
cd mobile_app
flutter pub get
flutter run
```

To run on Chrome/Web:
```bash
flutter run -d chrome
```

To run on an Android emulator or connected device:
```bash
flutter run -d android
```

---

## 7. QR Code Traceability & Public Verification

When honey is packaged into retail jars, the backend creates a `PackagingBatch` and a linked `QRCode` record with a unique cryptographic hash (`qr_hash`).

### Verification Flow

```text
Consumer scans QR Code / Opens Verification URL
                       ↓
GET /verify/{qr_hash}
                       ↓
Backend queries database for:
- Packaging details (Jar size, packaging date, unit serial)
- Lab Quality Report (Moisture %, Pollen count, HMF, Purity score, Certification)
- Processing details (Filtration grade, heating temperature, processing hub)
- Collection details (Collector ID, gross weight, collection timestamp)
- Harvester & Hive (Harvester name, hive code, apiary region, floral source)
                       ↓
Backend cross-references on-chain event hash with EVM contract:
HoneyChainProvenance.getEvents(batchId)
                       ↓
Returns complete cryptographic proof & audit timeline
```

Consumers can verify any product in the mobile application via **Public Verification Lookup** or by browsing to `http://localhost:8000/verify/<qr_hash>`.

---

## 8. Development & Contribution Guidelines

1. **Branch Protection:** All feature development, refactoring, and documentation updates must occur on `feature/development` or dedicated `feature/<name>` branches. **Never commit directly to `main`.**
2. **AI/ML Immutability:** Do not edit, format, or rename files inside `ai_ml/`. It is strictly read-only.
3. **Source Code Safety:** Ensure `.gitignore` never ignores `.dart`, `.py`, `.js`, `.ts`, `.sol`, or `.prisma` source code files.
4. **Testing:** Run backend integration tests prior to pushing changes:
   ```bash
   pytest backend/tests/test_e2e_integration.py
   ```
