# HoneyChain Windows Demo Runbook

Use this for local laptop simulation, Android emulator/phone, and a same-Wi-Fi ESP32 demo.

Repository root: `C:\Users\saksh\OneDrive\Desktop\HoneyChain`

Ports used by this repository (do not invent others):

| Service | Port |
|---|---|
| Mosquitto MQTT | 1883 |
| PostgreSQL | 5432 |
| FastAPI backend | 8000 |
| Local Hardhat / Ganache | 8545 |

Telemetry is stored in PostgreSQL. Blockchain stores provenance/traceability events only.

---

## A. One-time setup

From `C:\Users\saksh\OneDrive\Desktop\HoneyChain`:

```powershell
python -m venv .test-venv
.\.test-venv\Scripts\python -m pip install -r requirements-test.txt
cd blockchain
npm install
cd ..
cd mobile_app
flutter pub get
cd ..
Copy-Item backend\.env.example backend\.env
```

Edit untracked `backend\.env`:

- `DATABASE_URL=postgresql://<user>:<password>@<supabase-host>:5432/postgres` (Supabase PostgreSQL is authoritative; localhost Postgres is not used)
- `DEV_OFFLINE_SQLITE=false` (test-only offline mode; the app never falls back to SQLite automatically)
- `MQTT_HOST=localhost`
- `MQTT_PORT=1883`
- `MQTT_USERNAME=` and `MQTT_PASSWORD=` for this development broker (anonymous LAN/local config)
- `PORT` remains `8000`
- Fill `BLOCKCHAIN_PRIVATE_KEY` and `CONTRACT_ADDRESS` after the local node deploy step below. Never commit those values.

Create `iot\firmware\secrets.h` from `iot\firmware\secrets.example.h`. Do not commit `secrets.h`.

Find the laptop LAN IPv4:

```powershell
Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.PrefixOrigin -ne 'WellKnown' } | Select-Object IPAddress, InterfaceAlias
```

Use a private `192.168.x.x` / `10.x.x.x` address. Never use `127.0.0.1` for ESP32 or a physical phone.

---

## B–H. Local simulation (copy-paste)

Terminal 1 — PostgreSQL + Mosquitto — repository root:

```powershell
docker compose up -d postgres mosquitto
docker compose ps
```

Expected: both services healthy/running. If Docker PostgreSQL is unavailable, skip live DB checks and keep `DEV_OFFLINE_SQLITE=true` only for unit tests.

Terminal 2 — local chain — `blockchain\`:

```powershell
cd C:\Users\saksh\OneDrive\Desktop\HoneyChain\blockchain
npm run node
```

Expected: JSON-RPC on `127.0.0.1:8545` and printed development accounts.

Terminal 3 — deploy contract — `blockchain\`:

```powershell
cd C:\Users\saksh\OneDrive\Desktop\HoneyChain\blockchain
$env:BLOCKCHAIN_PRIVATE_KEY="<funded Hardhat account private key from Terminal 2>"
$env:BLOCKCHAIN_PROVIDER_URL="http://127.0.0.1:8545"
$env:BLOCKCHAIN_CHAIN_ID="31337"
npm run deploy
```

Copy the printed `CONTRACT_ADDRESS`, `BLOCKCHAIN_PROVIDER_URL`, and `BLOCKCHAIN_CHAIN_ID` into `backend\.env`.

Terminal 4 — FastAPI — `backend\`:

```powershell
cd C:\Users\saksh\OneDrive\Desktop\HoneyChain\backend
C:\Users\saksh\OneDrive\Desktop\HoneyChain\.test-venv\Scripts\uvicorn main:app --host 0.0.0.0 --port 8000

Expected: `http://127.0.0.1:8000/api/health` returns healthy.

Terminal 5 — AI processor — repository root:

```powershell
cd C:\Users\saksh\OneDrive\Desktop\HoneyChain
$env:MQTT_BROKER="localhost"
$env:MQTT_PORT="1883"
$env:DATABASE_URL="postgresql://<user>:<password>@<supabase-host>:5432/postgres"  # same DATABASE_URL as backend/.env
$env:AI_HISTORY_RELOAD="true"
.\.test-venv\Scripts\python -m ai_ml.mqtt.mqtt_processor
```

Expected: MQTT connect, then `Reloaded N telemetry readings from database history` (N can be 0 on a fresh database).

Terminal 6 — simulator — repository root:

Register hive `SIH_HIVE_MVP_01` in the app/API first, then:

```powershell
cd C:\Users\saksh\OneDrive\Desktop\HoneyChain
.\.test-venv\Scripts\python -m ai_ml.tests.mqtt_simulator --host 127.0.0.1 --port 1883 --topic honeychain/hive/telemetry --device-id SIH_HIVE_MVP_01 --count 145 --interval 0.05 --scenario normal
```

Expected: 145 telemetry publishes. After history is full, AI publishes to `honeychain/hive/processed`. Backend stores one telemetry row per timestamp.

Risk demos (same command, change `--scenario`):

- `normal` — in-range sensors
- `attention` — last packet temperature 37°C
- `alert` — last packet temperature/humidity/weight outside reference
- `ml` — last packet far from the Isolation Forest training distribution

These are risk/anomaly indicators, not disease diagnoses.

---

## I. Flutter desktop / emulator

From `mobile_app\`:

```powershell
cd C:\Users\saksh\OneDrive\Desktop\HoneyChain\mobile_app
flutter devices
flutter run --dart-define=BACKEND_URL=http://10.0.2.2:8000
```

Use `http://10.0.2.2:8000` for the Android emulator. Use `http://localhost:8000` for Windows desktop if you run `flutter run -d windows`.

---

## J. Physical Android phone

Phone and laptop must be on the same Wi-Fi. Replace `192.168.X.X` with the laptop LAN IPv4.

```powershell
cd C:\Users\saksh\OneDrive\Desktop\HoneyChain\mobile_app
flutter run --dart-define=BACKEND_URL=http://192.168.X.X:8000
```

Uvicorn must already be bound to `0.0.0.0:8000`.

---

## K–M. Real ESP32

1. Laptop and ESP32 on the same Wi-Fi.
2. Mosquitto already listens on `0.0.0.0:1883` in `mosquitto/mosquitto.conf`.
3. In `iot\firmware\secrets.h` set `mqtt_server` to the laptop LAN IPv4, `mqtt_port` to `1883`. Never `localhost`.
4. Map the firmware `device_id` (`HC-ESP32-A1B2C3D4` unless you change it) to a hive `device_id` in the backend.
5. Compile/upload from `iot\firmware\` with Arduino IDE or:

```powershell
arduino-cli compile --fqbn esp32:esp32:esp32 C:\Users\saksh\OneDrive\Desktop\HoneyChain\iot\firmware\esp32_honeychain.ino
arduino-cli upload -p COMx --fqbn esp32:esp32:esp32 C:\Users\saksh\OneDrive\Desktop\HoneyChain\iot\firmware\esp32_honeychain.ino
```

If `arduino-cli` is missing, compilation remains unverified until it is installed.

Private-network firewall for MQTT (do not use this on a public profile):

```powershell
New-NetFirewallRule -DisplayName "HoneyChain MQTT 1883" -Direction Inbound -Protocol TCP -LocalPort 1883 -Action Allow -Profile Private
New-NetFirewallRule -DisplayName "HoneyChain API 8000" -Direction Inbound -Protocol TCP -LocalPort 8000 -Action Allow -Profile Private
```

---

## N–S. Verification

MQTT:

```powershell
docker exec honeychain-mosquitto mosquitto_sub -t honeychain/hive/# -v -C 5
```

AI: processor logs show history count, then processed JSON after 145 readings.

Backend: `http://127.0.0.1:8000/docs` and `GET /api/health`.

PostgreSQL (when Docker Postgres is running):

```powershell
docker exec honeychain-postgres psql -U postgres -d honeychain -c "SELECT device_id, timestamp FROM hive_telemetry ORDER BY timestamp DESC LIMIT 5;"
docker exec honeychain-postgres psql -U postgres -d honeychain -c "SELECT device_id, risk_level FROM hive_ai_analysis ORDER BY created_at DESC LIMIT 5;"
```

Blockchain: `npm run test` and `npm run test:backend-evm` from `blockchain\`.

QR: create a packaging batch through the API/app, then open `http://127.0.0.1:8000/api/verify/{batch_id}` or `http://127.0.0.1:8000/api/traceability/{batch_id}`.

---

## T. AI restart resilience

1. Send 145 telemetry messages so `hive_telemetry` has history.
2. Stop the AI processor (Ctrl+C).
3. Start it again with the same `DATABASE_URL`.
4. Confirm the startup line reports reloaded readings (up to 145 per device).
5. Send one more telemetry packet.
6. Confirm processed output is produced without waiting for another 145 live packets.
7. Confirm PostgreSQL row counts do not double for the same `device_id` + `timestamp`.

If PostgreSQL is down, AI logs `Could not reload AI history from the database` and continues from live MQTT only.

---

## Tests

From repository root, with `.test-venv`:

```powershell
.\.test-venv\Scripts\python -m pytest backend/tests ai_ml/tests -q
cd blockchain
npm test
npm run test:backend-evm
cd ..\mobile_app
flutter test
flutter analyze
flutter build apk --debug
```

The checked-in Mosquitto config allows anonymous clients only on a trusted development LAN. Use authentication and TLS before any production deployment.
