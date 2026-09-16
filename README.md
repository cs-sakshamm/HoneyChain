# HoneyChain — End-to-End Honey Supply Chain Traceability

Blockchain-verified honey provenance: **ESP32 hive sensors → AI anomaly detection →
FastAPI backend → PostgreSQL → immutable provenance ledger → Flutter mobile app →
public QR verification** for the final consumer.

---

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          EDGE / SENSING LAYER                            │
│  iot/firmware/esp32_honeychain.ino (DHT22 + HX711 + acoustics)          │
│       publishes JSON → MQTT topic: honeychain/hive/telemetry            │
└───────────────────────────────┬─────────────────────────────────────────┘
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    MESSAGE BUS (mosquitto/mosquitto.conf)               │
│              Mosquitto broker :1883 (auth required)                     │
└──────────────┬──────────────────────────────────────┬───────────────────┘
               ▼                                      ▼
┌──────────────────────────────────┐   ┌──────────────────────────────────┐
│        AI/ML PROCESSOR           │   │   FASTAPI BACKEND (:8000)        │
│  ai_ml/mqtt/mqtt_processor.py    │   │   backend/main.py                │
│  ├─ FeatureBuilder (145 hist)    │   │   ├─ services/mqtt_consumer.py   │
│  ├─ IsolationForest anomaly      │──▶│   │   (subscribes BOTH topics:   │
│  └─ RiskEngine → risk level      │   │   │    raw + processed)          │
│  publishes → hive/processed      │   │   └─ WebSocket /ws/telemetry     │
└──────────────────────────────────┘   └───────┬──────────────┬───────────┘
                                               ▼              ▼
┌──────────────────────────────────┐   ┌──────────────────────────────────┐
│  POSTGRESQL 16                   │   │  BLOCKCHAIN LEDGER               │
│  backend/models.py (20 tables):  │   │  blockchain_service.py (Web3.py) │
│  Users, Profiles, Hives,         │   │  → HoneyChainProvenance.sol      │
│  Telemetry, AIAnalysis, Alerts,  │   │  (Hardhat :8545 / Polygon Amoy)  │
│  Batches, LabReports, QRs…       │   │  offline-safe hash fallback      │
└──────────────────────────────────┘   └──────────────────────────────────┘
                                               ▲
┌──────────────────────────────────────────────┴──────────────────────────┐
│                      FLUTTER MOBILE APP (mobile_app/)                   │
│  main.dart → 8 Providers → app.dart AuthRouter → 4 role shells:         │
│  ├─ HARVESTER:  hives/ (register, live telemetry, critical alerts)      │
│  ├─ COLLECTION: collection/ (requests → send-next state machine)        │
│  ├─ LAB:        lab/ (moisture/HMF/diastase certification)              │
│  ├─ PACKAGING:  packaging/ (final batch QR generation)                  │
│  └─ SHARED:     verification/ (OTP/KYC gates, public lookup)            │
│  REST base: AppConstants.backendBaseUrl (10.0.2.2:8000 on Android)      │
└───────────────────────────────┬─────────────────────────────────────────┘
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│         PUBLIC CONSUMER VERIFICATION  GET /verify?batch={batch_id}      │
│         HTML certificate (browser) + JSON (Flutter public lookup)       │
└─────────────────────────────────────────────────────────────────────────┘
```

### Data flow of a honey batch

1. **Harvester** registers hives, harvests honey, creates a collection request.
2. **Collection & Processing** accepts, extracts, creates `HC-BATCH-YYYY-XXXXXX`.
3. Every state transition is hashed (SHA-256) and recorded via `blockchain_service`
   → `HoneyChainProvenance.sol` (`recordEvent`), with an off-chain mirror in
   `blockchain_records`. If the chain node is down, tamper-evident hashes are
   logged for later reconciliation — the workflow never blocks.
4. **Lab** certifies moisture / HMF / diastase / F-G ratio / pollen.
5. **Packaging** seals jars and generates the final batch QR code.
6. **Consumer** scans QR → `/verify?batch=…` → full provenance certificate.

---

## 📁 Repository Layout

| Directory | What it is |
|---|---|
| `backend/` | **FastAPI** monolith — REST, WebSocket, MQTT consumer, blockchain writer, QR service, Alembic migrations, pytest suite |
| `mobile_app/` | **Flutter** app (harvester / collection / lab / packaging roles), 87 Dart files, provider state management |
| `blockchain/` | Solidity contract `HoneyChainProvenance.sol`, Hardhat config (localhost + Polygon Amoy), deploy script & tests |
| `ai_ml/` | Isolation-Forest anomaly detection over hive telemetry; MQTT in → processed out (untouched by integration work) |
| `iot/firmware/` | ESP32 Arduino sketch (DHT22 + HX711 → MQTT) |
| `mosquitto/` | Broker config (auth required) |
| `legacy/` | Archived deprecated Express/Prisma backend — see `legacy/README.md` |
| `scripts/` | Dev tooling (`start_dev.sh`, doc/report generators) |

---

## 🚀 Quick Start

### Option A — Docker (recommended)

```bash
# 1. Create broker credentials (first time only)
docker run --rm -v "$(pwd)/mosquitto:/mosquitto" eclipse-mosquitto:2 \
  mosquitto_passwd -c /mosquitto/config/passwd honeychain_backend
# → enter a password, then set MQTT_USERNAME=honeychain_backend and
#   MQTT_PASSWORD=<the password> in your shell or a root .env file.

# 2. Boot the whole stack
docker compose up -d

# 3. Optional: local blockchain ledger
docker compose --profile blockchain up -d

# 4. Check health
curl http://localhost:8000/api/health
```

### Option B — Native (no Docker)

```bash
./scripts/start_dev.sh           # broker + backend + AI processor
./scripts/start_dev.sh --chain   # …plus a local Hardhat node
```

Requires Python 3.11, mosquitto (or Docker for the broker), Node 18+.

### Mobile app

```bash
cd mobile_app
flutter pub get
flutter run        # Android emulator reaches backend via http://10.0.2.2:8000
```

For a physical device, build with a reachable backend URL:

```bash
flutter run --dart-define=BACKEND_URL=http://<your-lan-ip>:8000
```

### Simulate a hive (test the full pipeline)

```bash
python ai_ml/tests/mqtt_simulator.py     # publishes fake ESP32 telemetry
```

Then watch the Flutter harvester dashboard update, or:

```bash
docker exec -it honeychain-mosquitto mosquitto_sub -t 'honeychain/hive/#' -v
```

---

## 🔌 Key Integration Points

| Link | Where |
|---|---|
| Mobile ↔ Backend | `mobile_app/lib/core/constants/app_constants.dart` (`backendBaseUrl`) |
| Backend ↔ DB | `backend/database.py` (`DATABASE_URL`) |
| Backend ↔ Broker | `backend/services/mqtt_consumer.py` (`MQTT_HOST/USERNAME/PASSWORD`) |
| AI ↔ Broker | `ai_ml/mqtt/mqtt_processor.py` (same env vars) |
| Backend ↔ Chain | `backend/services/blockchain_service.py` (`BLOCKCHAIN_*`) |
| Contract config | `blockchain/hardhat.config.js`, `backend/.env.example` |
| Public QR URL | `backend/services/qr_service.py` (`PUBLIC_APP_URL`) |

All variable names are documented in `backend/.env.example` — copy it to
`backend/.env` and fill in real secrets.

---

## 🧪 Tests

```bash
cd backend && pytest -q                 # backend suite
cd blockchain && npm test               # Hardhat contract tests
cd mobile_app && flutter test           # 41 Flutter unit/widget tests
```

---

## 🔒 Security Notes

- JWT (HS256) auth on all write endpoints; role gates
  (`require_verified_harvester/collector/lab/packager`) enforce KYC server-side.
- Passwords hashed with bcrypt (legacy SHA-256 hashes are upgraded transparently).
- Mosquitto requires username/password (`allow_anonymous false`).
- The old hardcoded Hardhat dev key was removed from `blockchain_service.py`;
  supply `BLOCKCHAIN_PRIVATE_KEY` via env for testnet deploys.
