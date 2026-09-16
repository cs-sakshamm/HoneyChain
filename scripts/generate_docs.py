import os
from pathlib import Path

docs_dir = Path("docs")
docs_dir.mkdir(exist_ok=True)

# 1. DEPLOYMENT.MD
deployment_content = """# HoneyChain Production Deployment Guide

## 1. Architecture Overview
HoneyChain is an end-to-end decentralized and AI-powered honey traceability platform:
1. **IoT Edge Tier**: ESP32 microcontrollers measuring Temperature, Humidity (DHT22), Weight (HX711), and Acoustics (INMP441) publishing telemetry over MQTT (`honeychain/hive/telemetry`).
2. **AI/ML Analytics Tier**: Isolation Forest anomaly detection and rule heuristics operating over a 24-hour window, publishing processed metrics to `honeychain/hive/processed`.
3. **Backend API Tier**: FastAPI application handling multi-tier authentication, profile validation gates, PostgreSQL storage, blockchain hashing, and public verification API.
4. **Relational Database Tier**: Supabase PostgreSQL with SQLAlchemy ORM and Alembic migrations.
5. **Blockchain Tier**: Polygon Amoy smart contract (`HoneyChainProvenance.sol`) anchoring immutable multi-stage cryptographic proofs.
6. **Mobile Tier**: Flutter app providing tailored interfaces for Harvesters, Collectors, Labs, and Packagers.

---

## 2. Infrastructure Setup & Database Provisioning

### 2.1 Supabase PostgreSQL
1. Create a Supabase project at [supabase.com](https://supabase.com).
2. Retrieve the pooled connection URI from **Database > Connection Pooling**.
3. Set `DATABASE_URL` in `backend/.env`.

### 2.2 Database Migrations
Execute Alembic migrations to build the complete relational schema:
```bash
cd backend
alembic upgrade head
```

---

## 3. Backend Deployment

### 3.1 Environment Configuration
Copy `backend/.env.example` to `backend/.env` and supply production values:
```bash
cp backend/.env.example backend/.env
```

### 3.2 Running with Systemd (Linux Production)
Create `/etc/systemd/system/honeychain.service`:
```ini
[Unit]
Description=HoneyChain API Backend
After=network.target

[Service]
User=www-data
WorkingDirectory=/var/www/honeychain
EnvironmentFile=/var/www/honeychain/backend/.env
ExecStart=/var/www/honeychain/venv/bin/uvicorn backend.main:app --host 0.0.0.0 --port 8000 --workers 4
Restart=always

[Install]
WantedBy=multi-user.target
```

---

## 4. Blockchain Smart Contract Deployment

Deploy to Polygon Amoy testnet:
```bash
cd blockchain
npm install
npx hardhat run scripts/deploy.js --network amoy
```
Copy the deployed contract address to `backend/.env` under `CONTRACT_ADDRESS`.

---

## 5. IoT ESP32 Firmware Deployment

1. Open `iot/firmware/esp32_honeychain.ino` in Arduino IDE.
2. Configure WiFi credentials and MQTT Broker IP/hostname.
3. Flash the firmware to ESP32 boards deployed at apiaries.
"""

# 2. ENVIRONMENT.MD
environment_content = """# HoneyChain Environment Variables Specification

This document details all configuration parameters across HoneyChain services.

| Variable Name | Component | Type | Default Value | Description |
| :--- | :--- | :--- | :--- | :--- |
| `PORT` | Backend | Integer | `8000` | Port on which FastAPI server listens |
| `DATABASE_URL` | Backend | String (URI) | `postgresql://...` | PostgreSQL connection URI (Supabase pooler supported) |
| `DATABASE_POOL_SIZE` | Backend | Integer | `10` | SQLAlchemy connection pool size |
| `DATABASE_MAX_OVERFLOW`| Backend | Integer | `20` | Max overflow connections above pool size |
| `DATABASE_POOL_RECYCLE` | Backend | Integer | `1800` | Pool recycle timeout in seconds |
| `SECRET_KEY` | Backend | String | *Required* | 256-bit cryptographically secure key for JWT HMAC-SHA256 signing |
| `ALGORITHM` | Backend | String | `HS256` | JWT signing algorithm |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | Backend | Integer | `1440` | JWT token validity window in minutes |
| `WEB3_PROVIDER_URI` | Blockchain | String (URL) | `https://rpc-amoy.polygon.technology/` | RPC endpoint for Web3 interactions |
| `BLOCKCHAIN_CHAIN_ID` | Blockchain | Integer | `80002` | Network chain ID (Polygon Amoy) |
| `CONTRACT_ADDRESS` | Blockchain | String (Hex) | `0x...` | Deployed `HoneyChainProvenance` contract address |
| `PRIVATE_KEY` | Blockchain | String (Hex) | `0x...` | Relayer private key for signing provenance transactions |
| `BLOCKCHAIN_TIMEOUT_SECONDS` | Blockchain | Float | `2.0` | Timeout threshold before graceful fallback to offline SHA-256 |
| `MQTT_BROKER` | IoT / AI | String | `broker.hivemq.com` | Hostname or IP of MQTT broker |
| `MQTT_PORT` | IoT / AI | Integer | `1883` | Port for MQTT communications |
| `MQTT_TOPIC_TELEMETRY`| IoT / AI | String | `honeychain/hive/telemetry` | Raw telemetry publication topic |
| `MQTT_TOPIC_AI_PROCESSED` | AI / Backend | String | `honeychain/hive/processed` | Topic for AI/ML processed insights |
| `BACKEND_URL` | Mobile App | String (URL) | `http://10.0.2.2:8000` | Base URL passed via `--dart-define=BACKEND_URL` |
"""

# 3. DATABASE_MIGRATION.MD
migration_content = """# HoneyChain Database Migration Guide

## Overview
HoneyChain utilizes Alembic alongside SQLAlchemy 2.0 to maintain authoritative relational schemas on PostgreSQL and Supabase.

## Migration Files
- `backend/alembic.ini`: Configuration file defining logging and script directory.
- `backend/alembic/env.py`: Migration environment importing SQLAlchemy `Base.metadata` from `backend.models` and resolving `DATABASE_URL`.
- `backend/alembic/versions/eb21531004d8_initial_honeychain_schema.py`: Baseline migration establishing the complete HoneyChain schema.

## Schema Entities
1. `users`: Identity and profiles with bcrypt-hashed credentials, RBAC roles, contact data, and verification flags.
2. `hives`: Physical beehive registry linked to harvesters and IoT hardware device IDs.
3. `telemetry_readings`: Raw and AI-processed time-series metrics (temp, humidity, weight, acoustics, anomaly scores, health scores).
4. `collection_batches`: Honey harvest lots recording beekeeper source, quantities, and current workflow status.
5. `processing_logs`: Refining, moisture reduction, filtration, and processing metrics.
6. `lab_reports`: NABL laboratory test results (purity, moisture content, HMF, sucrose, pollen analysis).
7. `packaging_batches`: Final retail packaging, container counts, and public QR verification endpoints.
8. `blockchain_records`: On-chain transaction receipts, block numbers, and SHA-256 tamper-evident hashes.

## Running Migrations
To upgrade the database to the latest schema:
```bash
cd backend
alembic upgrade head
```

To roll back a migration:
```bash
cd backend
alembic downgrade -1
```
"""

# 4. ANDROID_RELEASE.MD
android_content = """# HoneyChain Android Release Guide

## Prerequisites
- Flutter SDK 3.47.2+
- Android SDK 34+
- Java JDK 17+

## 1. Environment & Backend Configuration
Configure the production backend URL using Flutter compile-time definitions (`--dart-define`):

```bash
cd mobile_app
flutter build apk --release --dart-define=BACKEND_URL=https://api.honeychain.io
```

## 2. Generating Release Keystore
Generate a signing keystore for production Android builds:
```bash
keytool -genkey -v -keystore android/app/honeychain-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias honeychain
```

Configure `android/key.properties`:
```properties
storePassword=<STORE_PASSWORD>
keyPassword=<KEY_PASSWORD>
keyAlias=honeychain
storeFile=honeychain-release.jks
```

## 3. Building App Bundle (AAB) & APK
For Google Play Store distribution:
```bash
flutter build appbundle --release --dart-define=BACKEND_URL=https://api.honeychain.io
```

For direct APK distribution:
```bash
flutter build apk --release --split-per-abi --dart-define=BACKEND_URL=https://api.honeychain.io
```

The output artifacts will be available in `build/app/outputs/flutter-apk/`.
"""

Path("docs/DEPLOYMENT.md").write_text(deployment_content.strip() + "\n", encoding="utf-8")
Path("docs/ENVIRONMENT.md").write_text(environment_content.strip() + "\n", encoding="utf-8")
Path("docs/DATABASE_MIGRATION.md").write_text(migration_content.strip() + "\n", encoding="utf-8")
Path("docs/ANDROID_RELEASE.md").write_text(android_content.strip() + "\n", encoding="utf-8")

print("Generated all 4 documentation files successfully.")
