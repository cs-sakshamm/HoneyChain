# HoneyChain Production Deployment Guide

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
