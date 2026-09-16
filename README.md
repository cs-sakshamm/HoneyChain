# HoneyChain
AI + IoT + Blockchain Powered Smart Beekeeping & Honey Traceability Platform

HoneyChain is an end-to-end platform for tracking honey from the hive to the consumer. It uses IoT sensors in the hive (ESP32) to collect telemetry, AI/ML to detect anomalies and forecast yield, a FastAPI backend with PostgreSQL for core logic, and a Polygon/Hardhat blockchain for immutable traceability. 

**Current Development Status:** Active Development
- Mobile Application: ✅ Complete (UI & core flows)
- Backend API: ✅ Complete (Core endpoints)
- PostgreSQL Database: ✅ Complete (Schema & migrations)
- Blockchain: 🟡 Partial (Contracts created, needs mainnet validation)
- AI/ML Integration: ✅ Complete (Anomaly detection implemented)
- IoT Integration: 🟡 Partial (MQTT configured, hardware pending)

## Table of Contents
1. [Project Overview](#1-project-overview)
2. [System Architecture](#2-system-architecture)
3. [Technology Stack](#3-technology-stack)
4. [Repository Structure](#4-repository-structure)
5. [Features](#5-features)
6. [User Roles](#6-user-roles)
7. [Authentication & Authorization](#7-authentication--authorization)
8. [Profile System](#8-profile-system)
9. [Harvester Workflow](#9-harvester-workflow)
10. [Collection & Processing Workflow](#10-collection--processing-workflow)
11. [Lab Workflow](#11-lab-workflow)
12. [Packaging Workflow](#12-packaging-workflow)
13. [Hive Management](#13-hive-management)
14. [IoT Architecture](#14-iot-architecture)
15. [MQTT](#15-mqtt)
16. [AI/ML Integration](#16-aiml-integration)
17. [Backend](#17-backend)
18. [API Documentation](#18-api-documentation)
19. [Database](#19-database)
20. [Blockchain](#20-blockchain)
21. [Smart Contract Workflow](#21-smart-contract-workflow)
22. [QR Verification](#22-qr-verification)
23. [Environment Variables](#23-environment-variables)
24. [Requirements](#24-requirements)
25. [Installation](#25-installation)
26. [Backend Setup](#26-backend-setup)
27. [Mobile App Setup](#27-mobile-app-setup)
28. [Blockchain Setup](#28-blockchain-setup)
29. [IoT Setup](#29-iot-setup)
30. [Running the Entire HoneyChain System](#30-running-the-entire-honeychain-system)
31. [Testing](#31-testing)
32. [End-to-End Testing](#32-end-to-end-testing)
33. [Real Data Policy](#33-real-data-policy)
34. [Error Handling](#34-error-handling)
35. [Known Issues](#35-known-issues)
36. [Remaining Work](#36-remaining-work)
37. [Developer Handoff Guide](#37-developer-handoff-guide)
38. [Git Workflow](#38-git-workflow)
39. [Security](#39-security)
40. [Production Deployment](#40-production-deployment)
41. [APK Build](#41-apk-build)
42. [Troubleshooting](#42-troubleshooting)
43. [FAQ](#43-faq)
44. [Project Status Dashboard](#44-project-status-dashboard)

## 1. Project Overview
HoneyChain digitizes the honey supply chain. It provides tools for harvesters to track hive health using IoT and AI, allows collection centers to process honey, labs to verify its purity, and packaging centers to generate QR codes containing the entire blockchain-backed history of the product for consumers to scan.

## 2. System Architecture
```text
Flutter Mobile App
        |
        v
Backend/API (FastAPI)
        |
        +------ PostgreSQL (Relational Data)
        |
        +------ Authentication (JWT)
        |
        +------ WebSocket (Real-time updates)
        |
        +------ QR Verification (Traceability)
        |
        v
IoT / MQTT (ESP32 -> Mosquitto)
        |
        v
AI/ML Processing (Anomaly Detection)
        |
        v
Processed Telemetry
        |
        v
Backend
        |
        v
Blockchain / Smart Contract (Hardhat / EVM)
        |
        v
QR / Public Verification
```

## 3. Technology Stack
| Component      | Technology                             | Purpose | Status |
| -------------- | -------------------------------------- | --------| ------ |
| Mobile         | Flutter / Dart                         | User Interface | ✅ |
| Backend        | FastAPI / Python                       | Core Logic | ✅ |
| Database       | PostgreSQL                             | Data Storage | ✅ |
| ORM            | SQLAlchemy                             | Database Mapping | ✅ |
| Blockchain     | Solidity / Hardhat / EVM               | Traceability | 🟡 |
| Communication  | REST / WebSocket / MQTT                | Connectivity | ✅ |
| IoT            | ESP32                                  | Hive Sensors | 🟡 |
| AI/ML          | Python ML pipeline                     | Anomaly Detection | ✅ |
| Authentication | JWT / Email & Password / Google OAuth  | Security | ✅ |
| QR             | qrcode (Python) / Flutter QR scanner   | Traceability UI | ✅ |

## 4. Repository Structure
```text
HoneyChain/
├── ai_ml/              # AI/ML anomaly detection and forecasting (DO NOT MODIFY)
├── backend/            # FastAPI backend, PostgreSQL models, REST & WebSocket APIs
│   ├── alembic/        # Database migrations
│   ├── services/       # Business logic layer
│   ├── tests/          # Pytest cases
│   ├── main.py         # Entry point, API routes
│   └── models.py       # SQLAlchemy database models
├── blockchain/         # Hardhat project, Solidity smart contracts for traceability
│   ├── contracts/      # Solidity contracts (HoneyChainProvenance.sol)
│   ├── scripts/        # Deployment scripts
│   └── test/           # Hardhat test files
├── docs/               # Additional documentation
├── iot/                # ESP32 firmware and IoT code
├── legacy/             # Legacy express backend code
├── mobile_app/         # Flutter mobile application
│   ├── android/        # Android native configuration
│   ├── ios/            # iOS native configuration
│   └── lib/            # Dart code for the app
├── mosquitto/          # MQTT broker configuration
├── scripts/            # Helper scripts
└── shared/             # Shared resources
```

## 5. Features
- **Authentication**: Email/password and Google Auth, JWT based. (✅ Completed)
- **Profile Management**: Profile completion enforcement per role. (✅ Completed)
- **Hive Management**: CRUD operations for hives. (✅ Completed)
- **IoT Telemetry**: Ingestion of telemetry data via MQTT. (✅ Completed)
- **Supply Chain Requests**: Sending, accepting, rejecting honey batches. (✅ Completed)
- **Blockchain Traceability**: Writing batch states to EVM. (🟡 Partially completed)

## 6. User Roles
- **Harvester**: Registers hives, monitors telemetry, creates collection requests.
- **Collection & Processing**: Receives requests, creates lab tests, manages processing.
- **Lab Test**: Receives lab tests, updates test status.
- **Packaging**: Receives lab-approved batches, generates QR codes.

## 7. Authentication & Authorization
Uses JWT for token generation. Passwords hashed using `bcrypt`.
Role-based access is implemented via backend dependency injection checking the token's role claim. Protected routes require `Bearer <Token>`.

## 8. Profile System
Incomplete profiles cannot perform role-specific operations.
The backend validates completeness (e.g., location, organization name, FSSAI license) before allowing operations like hive creation.

Incomplete Profile -> Tries protected operation -> Backend returns 403 Forbidden -> Client prompts "Complete your profile before continuing."

## 9. Harvester Workflow
Register/Login -> Complete Profile -> Add Hive (Generates Hive ID) -> Monitor Telemetry -> Send Collection Request -> Collection Center Accepts.

## 10. Collection & Processing Workflow
Collector accepts request -> Collector initiates processing -> Sends to Lab.
Lab requests specify nearest labs.

## 11. Lab Workflow
Lab receives test request -> Performs tests -> Updates test results -> Approved batches go to Packaging.
Updates the `LabReport` table in PostgreSQL.

## 12. Packaging Workflow
Packager receives batch -> Packager packages -> Backend creates blockchain record -> QR code is generated for the package ID.

## 13. Hive Management
Add Hive -> Generates unique Hive ID -> Can send/receive telemetry.
API: `POST /api/hives`, `GET /api/hives`.
Stores data in the `Hive` table.

## 14. IoT Architecture
ESP32 -> MQTT Broker (Mosquitto) -> MQTT Topic (`honeychain/hive/{hive_id}/telemetry`) -> AI/ML Processor -> Topic (`honeychain/hive/processed`) -> Backend (FastAPI).

## 15. MQTT
Configured in `mosquitto/`.
Backend subscribes to `honeychain/hive/processed`.
AI/ML subscribes to `honeychain/hive/telemetry`.
Payload structure: JSON with fields like temperature, humidity, weight.

## 16. AI/ML Integration
*DO NOT MODIFY `ai_ml/`.*
The AI/ML service listens to telemetry, runs inference pipelines to detect anomalies, and publishes results back to the MQTT broker. It operates as a distinct microservice communicating purely via MQTT.

## 17. Backend
Framework: FastAPI.
Database: PostgreSQL via SQLAlchemy.
Entry point: `backend/main.py`.

## 18. API Documentation
Swagger available at `http://localhost:8000/docs` when running.
Important APIs:
- `POST /api/auth/login`: Login
- `POST /api/auth/register`: Register
- `GET /api/profile`: Get user profile
- `POST /api/hives`: Create hive
- `POST /api/requests`: Create collection request
- `POST /api/telemetry/ingest`: Manual telemetry ingestion

## 19. Database
PostgreSQL.
Entities: User, Profile, Hive, Request, LabReport, Packaging.
Uses Alembic for migrations (`backend/alembic/`).

## 20. Blockchain
Framework: Hardhat.
Network: Local node or Polygon (configurable).
Smart Contract: `HoneyChainProvenance.sol`.

## 21. Smart Contract Workflow
Backend listens for final packaging step -> Submits transaction to blockchain -> Receives tx hash -> Stores tx hash in DB. Only essential traceability proofs (e.g. hashes, batch status) are stored on-chain, while full metadata lives in Postgres.

## 22. QR Verification
QR contains a URL linking to the public verification page on the frontend, which fetches traceability data from the backend. The journey maps from Hive -> Collector -> Lab -> Packaging.

## 23. Environment Variables
`backend/.env.example`:
```text
POSTGRES_USER=<YOUR_DB_USER>
POSTGRES_PASSWORD=<YOUR_DB_PASSWORD>
POSTGRES_DB=<YOUR_DB_NAME>
DATABASE_URL=postgresql://<YOUR_DB_USER>:<YOUR_DB_PASSWORD>@localhost:5432/<YOUR_DB_NAME>
JWT_SECRET_KEY=<YOUR_SECRET_KEY>
MQTT_HOST=localhost
BLOCKCHAIN_PROVIDER_URL=<YOUR_RPC_URL>
BLOCKCHAIN_PRIVATE_KEY=<YOUR_PRIVATE_KEY>
CONTRACT_ADDRESS=<YOUR_CONTRACT_ADDRESS>
GOOGLE_CLIENT_ID=<YOUR_GOOGLE_CLIENT_ID>
```
Do not expose real credentials!

## 24. Requirements
See `requirements.txt` and `backend/requirements.txt` for Python dependencies.
See `blockchain/package.json` for Node dependencies.
See `mobile_app/pubspec.yaml` for Flutter dependencies.

## 25. Installation
Prerequisites: 
- Git (`git --version`)
- Python 3.11 (`python --version`)
- Node.js 20 & npm (`node -v`, `npm -v`)
- Flutter SDK (`flutter --version`)
- PostgreSQL 16 (`psql --version`)
```bash
git clone <repository_url>
cd HoneyChain
```

## 26. Backend Setup
```bash
cd backend
python -m venv .venv
# Windows: .venv\Scripts\activate
# Linux/macOS: source .venv/bin/activate
pip install -r requirements.txt
# Set up .env based on .env.example
alembic upgrade head
uvicorn main:app --reload
```

## 27. Mobile App Setup
```bash
cd mobile_app
flutter pub get
flutter run
```
Use `http://10.0.2.2:8000` for Android emulator connection to the backend.

## 28. Blockchain Setup
```bash
cd blockchain
npm install
npx hardhat node
# In another terminal:
npx hardhat run scripts/deploy.js --network localhost
```

## 29. IoT Setup
Flash ESP32 firmware from `iot/` using PlatformIO or Arduino IDE. Configure Wi-Fi and MQTT broker IP in the firmware.

## 30. Running the Entire HoneyChain System
The recommended way is via Docker Compose for infrastructure:
```bash
docker compose --profile blockchain up -d
```
Then run the backend and flutter app locally. 

## 31. Testing
Backend: `cd backend && pytest`
Blockchain: `cd blockchain && npx hardhat test`
Mobile: `cd mobile_app && flutter test`

## 32. End-to-End Testing
1. Register user & Complete profile
2. Add hive
3. Push telemetry via API or MQTT
4. Create collection request
5. Log in as Collector -> Accept
6. Log in as Lab -> Test
7. Log in as Packager -> Package
8. Verify QR

## 33. Real Data Policy
No mock data should be hardcoded. The application relies entirely on PostgreSQL and the Blockchain for truth.

## 34. Error Handling
- **Database connection**: Check `DATABASE_URL`.
- **API 401**: Expired or missing JWT.
- **API 403**: Profile incomplete or wrong role.
- **MQTT connection**: Ensure Mosquitto is running on port 1883.

## 35. Known Issues
- Needs Mainnet deployment for Blockchain.
- IoT physical device testing requires physical setup.

## 36. Remaining Work
| Priority | Task | Component | Status | Notes |
|----------|------|-----------|--------|-------|
| High | E2E Integration | Integration | 🟡 | Connect all flows |
| Medium | Mainnet Deploy | Blockchain | 🔧 | Test on testnet first |
| Low | Offline mode | Mobile | ❌ | Planned feature |

## 37. Developer Handoff Guide
1. Clone repo
2. Install dependencies (Python, Node, Flutter, Postgres)
3. Start Postgres & Mosquitto via Docker
4. Start Hardhat Node & Deploy contract
5. Setup backend `.env` with DB and Contract address
6. Run migrations (`alembic upgrade head`)
7. Start backend (`uvicorn main:app --reload`)
8. Start mobile app (`flutter run`)

## 38. Git Workflow
```bash
git checkout -b feature/<feature-name>
# make changes
git add .
git commit -m "feat: description"
git push origin feature/<feature-name>
```
Create a Pull Request to `main`.

## 39. Security
- JWT keys must be cryptographically secure and injected via environment variables.
- Blockchain private keys must never be committed.
- Passwords are bcrypt hashed.
- Role-based route protection is active.

## 40. Production Deployment
- **Backend**: Use Gunicorn/Uvicorn behind Nginx/Traefik. HTTPS is mandatory.
- **Database**: Managed PostgreSQL (e.g. AWS RDS).
- **Blockchain**: Deploy to Polygon Mainnet.
- **MQTT**: Use a managed MQTT broker or secure Mosquitto with TLS.

## 41. APK Build
```bash
cd mobile_app
flutter build apk --release
```
APK is generated at `build/app/outputs/flutter-apk/app-release.apk`.

## 42. Troubleshooting
| Error | Likely Cause | Solution |
|-------|--------------|----------|
| Connection Refused (8000) | Backend not running | Start uvicorn |
| DB Error | Postgres not running / Wrong creds | Check Docker & `.env` |
| Flutter network error | Trying to reach localhost from device | Use machine's local IP |
| MQTT Error | Broker down | Start Mosquitto |

## 43. FAQ
- **What is HoneyChain?** A honey traceability platform.
- **Where is the backend?** `backend/` folder.
- **How does QR work?** Generates a link to the public verification endpoint.

## 44. Project Status Dashboard
| Component | Status | Evidence/Notes |
|-----------|--------|----------------|
| Flutter | ✅ Complete | UI and API integration present |
| Backend | ✅ Complete | FastAPI logic present |
| Database | ✅ Complete | SQLAlchemy models present |
| Authentication | ✅ Complete | JWT implemented |
| IoT | 🟡 Partial | Firmware exists, needs field testing |
| MQTT | ✅ Complete | Configured in docker-compose |
| AI/ML Integration | ✅ Complete | `ai_ml` folder present |
| Blockchain | 🟡 Partial | Contracts exist, needs mainnet |
| Smart Contracts | ✅ Complete | Solidity present |
| QR Verification | ✅ Complete | Endpoints present |
| Testing | 🔧 Needs validation | Pytest/Hardhat/Flutter tests |
| Deployment | 🔴 Not implemented | CI/CD missing |
