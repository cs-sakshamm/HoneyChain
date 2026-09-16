# HoneyChain

**HoneyChain** is an end-to-end, AI/ML-enabled, IoT-enabled, and Blockchain-backed honey traceability and quality verification supply-chain platform.

By integrating IoT sensors placed in apiaries, AI/ML anomaly detection, a robust FastAPI backend with PostgreSQL, an immutable blockchain ledger, and a cross-platform Flutter mobile application, HoneyChain provides complete transparency from the hive to the consumer's jar.

## The Complete Journey

HoneyChain tracks honey through a strictly enforced 5-stage pipeline:

1. **Harvester**: Beekeepers register their hives. IoT sensors stream live telemetry (temperature, humidity, acoustics, weight) from the hive. Harvesters log raw honey yields and initiate a collection request.
2. **Collection & Processing**: Processing centers accept raw honey, extract it, process it, and create tracked batches.
3. **Lab Test**: Accredited laboratories receive the processed batch to conduct moisture, HMF, diastase, and purity testing, generating certified lab reports.
4. **Packaging**: Certified batches are sealed in jars and given unique QR codes linked to their blockchain provenance record.
5. **Final QR Verification**: Consumers scan the QR code to view a complete, cryptographically verified history of the honey they purchased.

## Key Features

- **User Authentication**: Secure email/password authentication and Google authentication.
- **OTP & KYC**: Mobile OTP verification and Role-based KYC profile completion.
- **Role-Based Access**: Dedicated mobile app dashboards for Harvesters, Collectors, Lab Testers, and Packagers.
- **Harvester & Hive Management**: Register and monitor apiaries.
- **IoT Telemetry**: Real-time ESP32 data streaming via MQTT (temperature, humidity, weight).
- **AI/ML Processing**: Automated anomaly detection on hive telemetry to predict colony collapse or distress.
- **Collection & Processing**: Complete tracking of raw honey intake and batch processing.
- **Laboratory Testing**: 6-parameter quality analysis and certification logging.
- **Blockchain Traceability**: State transitions are hashed and securely recorded on a Solidity smart contract (Polygon Amoy / Hardhat).
- **QR Generation & Verification**: Consumer-facing web verification for authenticity.
- **Notifications & Alerts**: Real-time push alerts for critical hive events and workflow updates.

*(Note: All listed features are actively implemented and wired to the real backend and database.)*

## System Architecture

The HoneyChain ecosystem consists of several interconnected micro-components:

```mermaid
flowchart TD
    A[IoT Edge / ESP32] -->|MQTT| B(Mosquitto Broker)
    B -->|Raw Telemetry| C{AI/ML Processor}
    C -->|Processed / Risk Level| B
    B -->|WebSocket/MQTT| D(FastAPI Backend)
    D -->|CRUD| E[(PostgreSQL Database)]
    D -->|Smart Contract| F[Blockchain Ledger]
    G[Flutter Mobile App] <-->|REST API & WebSockets| D
    H[Consumer QR Scan] -->|GET /verify| D
```

### Data Flow

1. **IoT**: Hardware sensors send environmental data to the Mosquitto MQTT broker.
2. **AI/ML**: The AI processor consumes the raw telemetry, computes features, runs an Isolation Forest model to detect anomalies, and publishes the risk levels back to the broker.
3. **Backend**: The FastAPI backend subscribes to the broker, stores telemetry and alerts in the PostgreSQL database, and streams real-time data via WebSockets to the mobile app.
4. **Mobile App**: Users interact with the backend APIs to progress honey batches through the supply chain.
5. **Blockchain**: Critical batch state changes (e.g., harvesting, lab approval, packaging) trigger the backend to write a SHA-256 hash to the Ethereum/Polygon smart contract.
6. **QR Verification**: The generated QR code links directly to a backend endpoint which queries both the relational database and the blockchain ledger to produce an unforgeable certificate of authenticity.

## Project Structure

```text
HoneyChain/
├── ai_ml/              # READ-ONLY: Anomaly detection processor (Isolation Forest) & MQTT consumer
├── backend/            # FastAPI monolith, SQLAlchemy models, Alembic migrations, blockchain services
├── blockchain/         # Hardhat project, Solidity contracts, and deployment scripts
├── iot/                # ESP32 Arduino firmware and hardware documentation
├── mobile_app/         # Flutter application with role-specific dashboards
├── mosquitto/          # MQTT broker configuration
├── scripts/            # Development helper scripts
├── README.md           # This project documentation
└── requirements.txt    # Python backend dependencies
```

## Running the Complete Project

### Prerequisites

Ensure you have the following installed:
- **Git**
- **Flutter** (>= 3.0) & Dart
- **Python** (3.10 or 3.11)
- **Node.js** (>= 18.0) & npm
- **PostgreSQL** (>= 16)
- **Docker & Docker Compose** (Highly recommended for Mosquitto and local blockchain)

### 1. Environment Variables

Create `.env` files based on `.env.example` where applicable. **Never commit real secrets or private keys.**
Example variables required for the backend:
```env
DATABASE_URL=postgresql://user:pass@localhost/honeychain
SECRET_KEY=your_jwt_secret
MQTT_HOST=localhost
MQTT_USERNAME=admin
MQTT_PASSWORD=secret
BLOCKCHAIN_PRIVATE_KEY=0x...
```

### 2. Mosquitto (MQTT Broker)

Use Docker to spin up the required MQTT broker:
```bash
docker compose up -d mosquitto
```

### 3. Backend Setup

The backend relies on the `requirements.txt` located in the root (or `backend/requirements.txt`).
```bash
cd backend
python -m venv venv
# On Linux/Mac: source venv/bin/activate
# On Windows: venv\Scripts\activate
pip install -r ../requirements.txt

# Run database migrations
alembic upgrade head

# Start the FastAPI server
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### 4. AI/ML Setup

The AI/ML service runs independently, listening to the MQTT broker and processing data. Navigate to the `ai_ml/` directory and run its processor according to its own isolated setup. *(Note: The `ai_ml/` folder is strictly protected. Do not modify its contents.)*

### 5. Blockchain (Local Hardhat Node)

To test blockchain writes locally:
```bash
cd blockchain
npm install
npx hardhat node
```
*(In a separate terminal)*
```bash
npx hardhat run scripts/deploy.js --network localhost
```
Update your backend `.env` with the deployed contract address.

### 6. Mobile App Setup

The Flutter app connects to the FastAPI backend.
```bash
cd mobile_app
flutter pub get
```
To run on an Android emulator (which routes `10.0.2.2` to localhost):
```bash
flutter run
```
To run on a physical device, define your local machine's IP address:
```bash
flutter run --dart-define=BACKEND_URL=http://<your-lan-ip>:8000
```
