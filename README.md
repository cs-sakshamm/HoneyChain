# HoneyChain
AI + IoT + Blockchain Powered Smart Beekeeping & Honey Traceability Platform

HoneyChain is an end-to-end platform designed for tracking honey from the hive to the consumer. It integrates IoT sensors (ESP32) to collect hive telemetry, AI/ML to detect anomalies, a FastAPI backend with PostgreSQL for core logic, and a Polygon/Hardhat-based blockchain network for immutable traceability.

## Table of Contents
1. [Project Overview](#1-project-overview)
2. [System Architecture](#2-system-architecture)
3. [Technology Stack](#3-technology-stack)
4. [Project Completion Summary](#4-project-completion-summary)
5. [Repository Structure](#5-repository-structure)
6. [Data Flow](#6-data-flow)
7. [User Roles](#7-user-roles)
8. [Authentication & Authorization](#8-authentication--authorization)
9. [Environment Variables](#9-environment-variables)
10. [Installation Guide](#10-installation-guide)
11. [Setup & Run Guide](#11-setup--run-guide)
12. [API Documentation](#12-api-documentation)
13. [Database Documentation](#13-database-documentation)
14. [Blockchain Documentation](#14-blockchain-documentation)
15. [QR / Traceability Documentation](#15-qr--traceability-documentation)
16. [Testing Guide](#16-testing-guide)
17. [Troubleshooting](#17-troubleshooting)
18. [👨💻 New Developer Guide](#-new-developer-guide)
19. [Git / Branching Guide](#19-git--branching-guide)
20. [Real Data Policy](#20-real-data-policy)
21. [Documentation Changelog](#21-documentation-changelog)

---

## 1. Project Overview
HoneyChain digitizes the honey supply chain. It provides tools for harvesters to track hive health using IoT and AI, allows collection centers to process honey, labs to verify its purity, and packaging centers to generate QR codes containing the entire blockchain-backed history of the product for consumers to scan.

---

## 2. System Architecture

```text
Flutter Mobile App (UI & UX)
       |
       | REST / WebSocket
       v
FastAPI Backend (Core API)
       |
       +------ PostgreSQL (Relational Data & States)
       |
       +------ Authentication (JWT, Google Auth)
       |
       +------ MQTT / IoT (Mosquitto Broker)
       |       |
       |       +-- ESP32 Devices (Sensors)
       |
       +------ AI/ML Integration (Anomaly Detection)
       |
       +------ Blockchain (EVM / Smart Contracts)
       |
       +------ QR Verification (Traceability)
```

---

## 3. Technology Stack

### Mobile / Frontend
- **Flutter** & **Dart**
- **Libraries Used**: `firebase_auth`, `google_sign_in`, `provider`, `qr_flutter`, `http`

### Backend
- **Python 3**
- **FastAPI** (REST API & WebSocket)
- **SQLAlchemy** (ORM) & **Alembic** (Migrations)

### Database
- **PostgreSQL 16**

### Blockchain
- **Solidity** (Smart Contracts)
- **Hardhat** (Development & Deployment)
- **Network**: Polygon Amoy / Local Hardhat Node

### IoT
- **ESP32** (Microcontroller)
- **Sensors**: DHT22 (Temp/Humidity), HX711 (Weight Cell)
- **MQTT**: PubSubClient (Device), Mosquitto (Broker)

### AI/ML
- **Python ML Pipeline** (scikit-learn, pandas, etc.)
- *Note: This is a read-only component and must not be modified.*

### Authentication
- **Google Authentication** (Firebase/Server-side token verification)
- **Email/Password** (JWT with bcrypt hashing)
- **OTP/2FA** (Implemented in DB models, requires integration)

### Tools
- **Git** & **GitHub**
- **Docker** (Infrastructure)
- **VS Code** / **Android Studio**

---

## 4. Project Completion Summary

### Major Components: 7

| Component | Status | Current Implementation | Remaining Work |
|-----------|--------|------------------------|----------------|
| **Flutter App** | ✅ Completed | Core UI, API integration, Auth, QR scanning. | Offline mode implementation, full E2E UI testing. |
| **Backend** | ✅ Completed | FastAPI, Role-based auth, IoT ingestion, DB integration. | Performance tuning, E2E production tests. |
| **Database** | ✅ Completed | PostgreSQL models, relationships, Alembic migrations. | No major database work remaining. |
| **Blockchain** | 🟡 Partially Completed | `HoneyChainProvenance.sol` created, Hardhat configured. | Testnet/Mainnet deployment, rigorous contract testing. |
| **IoT** | 🟡 Partially Completed | `esp32_honeychain.ino` written, reads sensors, publishes to MQTT. | Physical field testing, dynamic WiFi provisioning. |
| **AI/ML** | Read Only | Anomaly detection pipeline built, MQTT listeners active. | (None - Component is read-only) |
| **Testing** | 🔧 Needs Validation| Unit tests exist for backend. | E2E Integration testing across the entire system. |

**Remaining Work Breakdown**:
- **Flutter**: Task 1 (Offline Mode)
- **Blockchain**: Task 1 (Mainnet Deployment), Task 2 (Integration validation)
- **IoT**: Task 1 (Physical device testing)
- **Testing**: Task 1 (E2E full pipeline test)
- **Deployment**: Task 1 (CI/CD pipeline setup), Task 2 (Production environment provisioning)

**Total Remaining Tasks: 7**

---

## 5. Repository Structure

```text
HoneyChain/
│
├── mobile_app/         # Flutter mobile application
├── backend/            # FastAPI backend, PostgreSQL models, Alembic
├── blockchain/         # Hardhat project, Solidity contracts
├── ai_ml/              # AI/ML anomaly detection (⚠️ STRICTLY READ-ONLY)
├── iot/                # ESP32 firmware (.ino)
├── mosquitto/          # MQTT broker configuration
├── docs/               # Additional documentation
├── docker-compose.yml  # Local infrastructure orchestration
└── README.md           # This file
```

- **mobile_app/**: Contains the Flutter app. Run with `flutter run`.
- **backend/**: Contains the FastAPI app, services, and models. Run with `uvicorn main:app`.
- **blockchain/**: Contains `HoneyChainProvenance.sol` and deployment scripts. Deploy with `npx hardhat run`.
- **iot/**: Contains `esp32_honeychain.ino` firmware. Flash using Arduino IDE.
- **ai_ml/**: Contains the ML pipelines. Do not modify.

---

## 6. Data Flow

1. **IoT Collection**: ESP32 sensors read Temperature, Humidity, and Weight.
2. **MQTT Ingestion**: Data is published to Mosquitto MQTT broker (`honeychain/hive/telemetry`).
3. **AI/ML Processing**: The read-only AI service ingests telemetry, detects anomalies, and outputs to `honeychain/hive/processed`.
4. **Backend Storage**: FastAPI subscribes to processed data and stores it in PostgreSQL.
5. **Supply Chain Workflow**: Harvester creates a request -> Collection Center accepts & processes -> Lab tests and approves -> Packaging Center packages.
6. **Blockchain Anchoring**: Upon packaging, a final state hash is committed to the Polygon blockchain via Hardhat scripts.
7. **QR Traceability**: A QR code is generated containing a verification URL. Consumers scan the QR to fetch supply chain history and verify blockchain proofs.

---

## 7. User Roles

1. **HARVESTER**
   - **Registration & Profile**: Must complete KYC and profile to manage hives.
   - **Hive Management**: Adds hives, registers IoT devices.
   - **Workflow**: Monitors telemetry, triggers honey collection requests.
2. **COLLECTION_PROCESSING**
   - **Workflow**: Accepts collection requests from harvesters, records processing data (e.g., moisture reduction), forwards to Lab.
3. **LAB_TESTING**
   - **Workflow**: Receives batches, conducts quality/purity tests (HMF, Diastase, Adulteration). Approves or rejects batches.
4. **PACKAGING**
   - **Workflow**: Receives approved batches, divides into consumer packages, triggers blockchain commit, generates final QR codes.
5. **ADMIN**
   - System monitoring, role management.

---

## 8. Authentication & Authorization

- **Methods**: Email/Password and Google OAuth.
- **Token**: JWT (JSON Web Tokens) are generated and required as `Bearer <Token>`.
- **Security**: Passwords hashed via `bcrypt`.
- **Role Isolation**: Backend endpoints enforce RBAC (Role-Based Access Control). A Harvester cannot access Lab endpoints.
- **Profile Completion**: Users cannot execute business operations until their profile (e.g., FSSAI license, location) is marked complete.

---

## 9. Environment Variables

Variables read by the application (found in `backend/.env.example`):

```ini
PORT=8000
ENVIRONMENT=development
LOG_LEVEL=INFO

DATABASE_URL=postgresql://postgres:postgres@localhost:5432/honeychain
DEV_OFFLINE_SQLITE=false

JWT_SECRET_KEY=your_secret_key_here
JWT_ALGORITHM=HS256
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=1440

GOOGLE_CLIENT_ID=your_google_client_id

MQTT_HOST=localhost
MQTT_PORT=1883
MQTT_USERNAME=honeychain_backend
MQTT_PASSWORD=your_mqtt_password
MQTT_INPUT_TOPIC=honeychain/hive/telemetry
MQTT_OUTPUT_TOPIC=honeychain/hive/processed

BLOCKCHAIN_PROVIDER_URL=http://127.0.0.1:8545
BLOCKCHAIN_PRIVATE_KEY=your_private_key
CONTRACT_ADDRESS=your_contract_address
BLOCKCHAIN_NETWORK_NAME=amoy

PUBLIC_APP_URL=http://127.0.0.1:8000
```
*Never commit `.env` with actual secrets!*

---

## 10. Installation Guide

**Prerequisites:**
Check if you have the required tools installed:
- **Git**: `git --version`
- **Python**: `python --version` (3.11+ recommended)
- **Node.js**: `node -v`, `npm -v` (v20+ recommended)
- **Flutter**: `flutter --version`
- **PostgreSQL**: `psql --version` (v16+)

*(Optional but recommended)*: Docker & Docker Compose (`docker --version`).

---

## 11. Setup & Run Guide

**1. Clone the repository**
```bash
git clone <repository_url>
cd HoneyChain
```

**2. Start Infrastructure (PostgreSQL & MQTT)**
Using Docker Compose is the easiest method:
```bash
docker-compose up -d postgres mosquitto
```

**3. Configure Environment**
```bash
cd backend
cp .env.example .env
# Edit .env with your local settings (e.g. DATABASE_URL)
```

**4. Start Backend**
```bash
# Windows PowerShell
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt

# Apply Migrations
alembic upgrade head

# Run server
uvicorn main:app --reload
```

**5. Start Blockchain (Local Node)**
Open a new terminal:
```bash
cd blockchain
npm install
npx hardhat node
```
In another terminal, deploy the contracts:
```bash
cd blockchain
npx hardhat run scripts/deploy.js --network localhost
# Update CONTRACT_ADDRESS in backend/.env with the output address.
```

**6. Start Mobile App**
Open a new terminal:
```bash
cd mobile_app
flutter pub get
flutter run
```

---

## 12. API Documentation

Full Swagger documentation is available at `http://localhost:8000/docs` when the backend is running.

**Key Endpoints:**
- `POST /api/auth/register` - Registers a user.
- `POST /api/auth/login` - Authenticates and returns JWT.
- `GET /api/profile` - Fetches the user profile (Requires Auth).
- `POST /api/hives` - Creates a new hive (Requires Harvester Auth).
- `POST /api/requests` - Creates a honey collection request.

---

## 13. Database Documentation

**Engine**: PostgreSQL
**ORM**: SQLAlchemy

**Core Models & Relationships**:
- `User` 1:1 `Profile`
- `User` 1:N `Hive`
- `Hive` 1:N `HiveTelemetry`, `HiveAIAnalysis`
- `Harvest`, `CollectionRequest`, `CollectionBatch`, `ProcessingBatch`, `LabReport`, `PackagingBatch` map the supply chain lifecycle linearly.
- `BlockchainRecord` stores immutable transaction hashes related to specific batches.
- `QRCode` maps physical labels to the verification URL.

---

## 14. Blockchain Documentation

**Network**: Polygon Amoy / Local Hardhat
**Contract**: `HoneyChainProvenance.sol`
- **Functions**: `recordEvent()`, `recordHarvesterVerification()`, `getEvents()`
- **Storage**: We store batch hashes, actor IDs, and previous event hashes on-chain. Large metadata remains in PostgreSQL.
- **Workflow**: 
  1. Backend detects a completed supply chain phase.
  2. Generates SHA256 hash of the data.
  3. Signs and submits a transaction via `web3` / JSON-RPC.
  4. Stores the resulting `txHash` in the PostgreSQL `blockchain_records` table.

---

## 15. QR / Traceability Documentation

- **Creation**: At the Packaging step, the backend dynamically generates a QR Code data URI containing the Verification URL.
- **Verification**: The consumer scans the code, which queries the backend.
- **Checking**: The backend fetches all states (Harvest -> Collection -> Lab -> Packaging) and their corresponding Blockchain TxHashes to prove data was not altered.

---

## 16. Testing Guide

**Manual End-to-End Workflow:**
1. Create a Harvester account -> Complete Profile.
2. Add a Hive -> Inject dummy telemetry via API or MQTT.
3. Trigger a Collection Request.
4. Login as Collector -> Accept Request -> Process -> Send to Lab.
5. Login as Lab -> Run tests -> Submit positive `LabReport`.
6. Login as Packager -> Receive batch -> Package -> View generated QR code.
7. Scan QR to verify end-to-end traceability.

*(For Automated tests, run `pytest` in `backend/` and `npx hardhat test` in `blockchain/`)*

---

## 17. Troubleshooting

- **Database Connection Failed**: Ensure PostgreSQL is running. Check `DATABASE_URL` in `.env`.
- **Port 8000 already in use**: Kill the existing process or run FastAPI on another port: `uvicorn main:app --port 8080`.
- **Flutter Network Error (Emulator)**: Use `10.0.2.2` instead of `localhost` in the app configuration if running in an Android Emulator.
- **MQTT Connection Refused**: Ensure Mosquitto broker is running locally on port 1883.
- **Blockchain Error**: Ensure Hardhat node is running and the `CONTRACT_ADDRESS` matches the newly deployed contract.

---

## 18. 👨💻 New Developer Guide

Welcome to HoneyChain! 
**Day 1 Checklist:**
1. Clone the repository.
2. Ensure you have Python, Node, Flutter, and Docker installed.
3. Start PostgreSQL and Mosquitto (`docker-compose up -d postgres mosquitto`).
4. Setup the backend `.env` (copy from `.env.example`).
5. Run DB migrations (`alembic upgrade head`).
6. Start the backend (`uvicorn main:app --reload`).
7. Run the Flutter frontend (`flutter run`).

**Important Rules before changing code:**
- **DO NOT TOUCH `ai_ml/`**: This module is strictly read-only and maintained separately.
- Read this README and the Architecture diagram.
- Check the "Remaining Work" section.
- Test your changes end-to-end.

---

## 19. Git / Branching Guide

Use feature branches for development. Do not push directly to `main`.

```bash
git checkout main
git pull origin main
git checkout -b feature/your-feature-name

# Make changes...
git add .
git commit -m "feat: add your feature description"
git push origin feature/your-feature-name
```
Open a Pull Request on GitHub to merge into `main`.

---

## 20. Real Data Policy

**HoneyChain should use real backend/database/JSON/API/blockchain data in production workflows. Dummy/mock data must not be used as a substitute for actual application data.**
Currently, IoT ESP32 firmware contains dummy fallback values for sensors if hardware fails. This should be replaced in production.

---

## 21. Documentation Changelog

Date: 2026-09-16

Updated:
- Complete project architecture
- Technology stack
- Installation instructions
- API documentation
- Database documentation
- Blockchain documentation
- Remaining work
- Testing instructions
- New developer guide
- Troubleshooting
- Explicit AI/ML Read-Only notices added.
