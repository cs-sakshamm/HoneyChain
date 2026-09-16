# HoneyChain
AI + IoT + Blockchain Powered Smart Beekeeping & Honey Traceability Platform

HoneyChain is an end-to-end platform for tracking honey from the hive to the consumer. It uses IoT sensors in the hive (ESP32) to collect telemetry, AI/ML to detect anomalies and forecast yield, a FastAPI backend with PostgreSQL for core logic, and a Polygon/Hardhat blockchain for immutable traceability. The Flutter mobile application allows users to interact with the system across different roles, and consumers can verify honey provenance via QR codes.

## System Architecture

```text
ESP32 / IoT Sensors
        |
      MQTT (Mosquitto)
        |
AI/ML Processing (Anomaly Detection)
        |
Processed Telemetry
        |
Backend / FastAPI (Python)
        |
PostgreSQL (Relational Database)
        |
Flutter Mobile App (Dart)
        |
Supply Chain Workflow (Roles)
        |
Blockchain (Solidity / Hardhat / EVM)
        |
QR Verification
        |
Public Verification
```

## Directory Structure

```text
HoneyChain/
├── ai_ml/              # AI/ML anomaly detection and forecasting (DO NOT MODIFY)
├── backend/            # FastAPI backend, PostgreSQL models, REST & WebSocket APIs
├── blockchain/         # Hardhat project, Solidity smart contracts for traceability
├── docs/               # Additional documentation
├── iot/                # ESP32 firmware and IoT code
├── legacy/             # Legacy express backend code
├── mobile_app/         # Flutter mobile application
├── mosquitto/          # MQTT broker configuration
├── scripts/            # Helper scripts
└── shared/             # Shared resources
```

## Technology Stack

| Component      | Technology                             |
| -------------- | -------------------------------------- |
| Mobile         | Flutter / Dart                         |
| Backend        | FastAPI / Python                       |
| Database       | PostgreSQL                             |
| ORM            | SQLAlchemy                             |
| Blockchain     | Solidity / Hardhat / EVM               |
| Communication  | REST / WebSocket / MQTT                |
| IoT            | ESP32                                  |
| AI/ML          | Existing AI/ML pipeline                |
| Authentication | JWT / Email & Password / Google OAuth  |
| QR             | qrcode (Python) / Flutter QR scanner   |

## Installation Guide & Prerequisites

*   **Git**: Required to clone the repository. `git --version`
*   **Python 3.11+**: Required for backend and AI/ML. `python --version`
*   **Node.js 20+ & npm**: Required for blockchain/Hardhat. `node -v`, `npm -v`
*   **Flutter & Dart**: Required for mobile app. `flutter --version`
*   **PostgreSQL 16**: Database. `psql --version`
*   **Docker & Docker Compose**: Recommended for running Mosquitto, PostgreSQL, AI/ML and Hardhat. `docker-compose version`

## Clone the Project

```bash
git clone <repository_url>
cd HoneyChain
```

## Environment Variables

Copy the example environment files where applicable. The main ones are in `backend/`.

**backend/.env** (Create this based on `backend/.env.example`):
```text
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=honeychain
POSTGRES_PORT=5432
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/honeychain
MQTT_HOST=localhost
MQTT_PORT=1883
MQTT_USERNAME=
MQTT_PASSWORD=
MQTT_INPUT_TOPIC=honeychain/hive/telemetry
MQTT_OUTPUT_TOPIC=honeychain/hive/processed
JWT_SECRET_KEY=your_secret_key
BLOCKCHAIN_PROVIDER_URL=http://localhost:8545
BLOCKCHAIN_PRIVATE_KEY=your_private_key
CONTRACT_ADDRESS=your_contract_address
PUBLIC_APP_URL=http://localhost:8000
GOOGLE_CLIENT_ID=
ENV=development
```
Never commit real passwords or private keys.

## Database Setup

1. Install PostgreSQL.
2. Create database:
```bash
createdb -U postgres honeychain
```
3. Use Alembic for migrations (from backend folder):
```bash
cd backend
alembic upgrade head
```

## Backend Setup

1. Navigate to the backend:
```bash
cd backend
```
2. Create and activate a virtual environment:
```bash
# Windows
python -m venv .venv
.venv\Scripts\activate
# Linux/macOS
python -m venv .venv
source .venv/bin/activate
```
3. Install dependencies:
```bash
pip install -r requirements.txt
```
4. Run the backend:
```bash
uvicorn main:app --reload
```
The FastAPI Swagger UI will be available at `http://localhost:8000/docs`.

## Backend API Documentation

Check `http://localhost:8000/docs` for the interactive OpenAPI documentation.
Major routes include:
*   `POST /api/auth/...`: Authentication
*   `GET /api/hives/...`: Hive management
*   `POST /api/telemetry/...`: Manual telemetry insert
*   `GET /api/blockchain/...`: Traceability

## Mobile App Setup

1. Navigate to mobile app:
```bash
cd mobile_app
```
2. Install dependencies:
```bash
flutter pub get
```
3. Run the app:
```bash
flutter run
```
Note: If using an Android Emulator, it connects to localhost backend via `http://10.0.2.2:8000`. If using a physical device, update the backend IP to your machine's local network IP.

## Blockchain Setup

1. Navigate to blockchain directory:
```bash
cd blockchain
```
2. Install dependencies:
```bash
npm install
```
3. Run local Hardhat node:
```bash
npx hardhat node
```
4. Deploy contracts (in a new terminal):
```bash
npx hardhat run scripts/deploy.js --network localhost
```
Update your backend `.env` with the deployed `CONTRACT_ADDRESS`.

## IoT + MQTT

The ESP32 devices publish to `honeychain/hive/{hive_id}/telemetry`.
Mosquitto broker receives this. AI/ML consumes it, processes it, and publishes to `honeychain/hive/processed`. The backend consumes this processed data and saves it to PostgreSQL.

## AI/ML Integration

The existing `ai_ml/` directory handles anomaly detection and yield forecasting.
It listens to MQTT telemetry, runs inference pipelines, and publishes processed data back to MQTT. (No modifications made to `ai_ml/`).

## User Roles

*   **Harvester**: Registers hives, views telemetry.
*   **Collection & Processing**: Collects honey from harvester.
*   **Lab Test**: Updates testing status.
*   **Packaging**: Finalizes packaging and issues QR codes.

## Complete Supply-Chain Workflow

Harvester -> Hive Registration -> IoT Telemetry -> Collection & Processing -> Lab Testing -> Packaging -> Blockchain Record -> Final QR -> Public Verification.

## Authentication & Security

Uses JWT (JSON Web Tokens) for authentication. Supports role-based access. Passwords are encrypted using bcrypt.

## Real Data Policy

No dummy or hardcoded production data should be used where real backend/API/database/blockchain data is expected.

## Testing

*   Backend: `pytest` in `backend/`
*   Blockchain: `npx hardhat test` in `blockchain/`
*   Mobile: `flutter test` in `mobile_app/`

## Troubleshooting

*   **Port in use**: Check if Docker or another process is using port 8000 (backend), 5432 (postgres), or 1883 (mqtt).
*   **Database connection**: Check PostgreSQL service and `DATABASE_URL`.
*   **Flutter backend connection**: Ensure correct IP is used (10.0.2.2 for emulator).

## Running HoneyChain Completely

Using Docker Compose is the easiest way to start infrastructure:
```bash
docker compose --profile blockchain up -d
```
Then run the backend and mobile app manually as described above.

## Development Workflow

1. Clone repository
2. Create branch: `git checkout -b feature/name`
3. Make changes and test
4. Commit: `git commit -m "..."`
5. Push: `git push origin feature/name`
6. Create PR

## Git Workflow

```bash
git status
git branch
git checkout -b feature/<name>
git add .
git commit -m "..."
git push origin feature/<name>
```

## Implemented vs Remaining Work

| Module          | Status | Completed | Remaining Work |
| --------------- | ------ | --------- | -------------- |
| Mobile App      | Active | UI, Auth  | Full integration testing |
| Backend         | Active | Auth, API | Full blockchain integration |
| Database        | Active | Schema    | Seed data strategy |
| Blockchain      | Active | Contracts | Mainnet deployment |
| IoT             | Active | Firmware  | Hardware deployment |
| AI/ML           | Active | Models    | Continuous training |

## Known Issues

*   Some mobile UI flows may need refinement for edge cases.

## Future Improvements

*   Mainnet deployment for blockchain.
*   Enhanced AI model accuracy.
