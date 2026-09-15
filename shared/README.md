# HoneyChain — Shared Types, Contracts & State Machine Specification

The `shared` module defines the canonical data models, standardized entity identifiers, state machine transitions, and cross-subsystem contracts across the entire HoneyChain platform. It ensures seamless interoperability between the Flutter Mobile Application, FastAPI Backend, EVM Blockchain Layer, IoT ESP32 Nodes, and the AI/ML Engine.

---

## 1. Unified Entity Identifiers

To maintain data integrity across distributed components (relational database, blockchain events, MQTT packets, and physical QR codes), all modules adhere to unified identifier formats:

| Identifier | Format Pattern | Example | Responsible Subsystem |
| :--- | :--- | :--- | :--- |
| `user_id` | UUID v4 | `a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d` | Backend (`users` table) / Firebase |
| `beekeeper_id` | `HC-BK-<HEX8>` | `HC-BK-97FD3395` | Harvester Profile / KYC |
| `hive_id` | UUID v4 | `f47ac10b-58cc-4372-a567-0e02b2c3d479` | Backend (`hives` table) |
| `device_id` | String code | `SIH_HIVE_MVP_01` | IoT Hardware & AI Processor |
| `collection_request_id` | UUID v4 | `b8e1a7b3-c9d2-4e5f-8a1b-3c4d5e6f7a8b` | Harvester / Collector |
| `collection_batch_id` | `CB-<UUID>` | `CB-98234-A78B` | Collector Aggregation |
| `processing_batch_id` | `PB-<UUID>` | `PB-55412-C32E` | Processing Hub |
| `lab_report_id` | UUID v4 | `e9f2a1b4-7c3d-4e8f-9a1b-2c3d4e5f6a7b` | Quality Testing Lab |
| `packaging_batch_id` | `PKG-<UUID>` | `PKG-77123-D91A` | Packaging Facility |
| `qr_hash` | SHA-256 (64 hex chars) | `7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069` | QR Code / Public Verification |

---

## 2. Global Supply Chain State Machine

A honey batch strictly transitions through sequential, verified lifecycle states:

```text
[ HARVESTED ]
      │
      ▼
[ COLLECTION_REQUESTED ] ──► (Collector schedules pickup)
      │
      ▼
[ COLLECTED ] ─────────────► (On-Chain Blockchain Event: "COLLECTION")
      │
      ▼
[ IN_PROCESSING ]
      │
      ▼
[ PROCESSED ] ─────────────► (On-Chain Blockchain Event: "PROCESSING")
      │
      ▼
[ LAB_SUBMITTED ]
      │
      ├───────────────────────────────┐
      ▼ (Fails standards)             ▼ (Passes standards)
[ LAB_REJECTED ]               [ LAB_CERTIFIED ] ──► (On-Chain: "LAB_TEST")
                                      │
                                      ▼
                               [ PACKAGED ] ───────► (On-Chain: "PACKAGING")
                                      │
                                      ▼
                               [ QR_GENERATED ]
                                      │
                                      ▼
                               [ PUBLIC_VERIFIED ]
```

### State Machine Transition Invariants

1. **Monotonic Progression:** A batch cannot skip states (e.g., honey cannot be packaged without a certified `LAB_REPORT`).
2. **Quality Gate:** If a batch is marked `LAB_REJECTED` (e.g., moisture > 20%, HMF > 40 mg/kg, or positive C4 adulteration), it cannot advance to `PACKAGED`.
3. **Cryptographic Sealing:** State changes (`COLLECTED`, `LAB_CERTIFIED`, `PACKAGED`) trigger deterministic SHA-256 hashing and commit a transaction to the `HoneyChainProvenance.sol` smart contract.

---

## 3. Canonical Cross-Module Data Contracts

### A. Raw IoT Telemetry Contract (ESP32 -> MQTT Broker -> AI/ML & Backend)
* **Topic:** `honeychain/hive/telemetry`
```json
{
  "device_id": "SIH_HIVE_MVP_01",
  "timestamp": 1725879172,
  "sensors": {
    "weight_kg": 3.25,
    "temperature_c": 34.2,
    "humidity_pct": 61.5,
    "acoustics_hz": 245
  },
  "diagnostics": {
    "battery_v": 4.12,
    "wifi_rssi_dbm": -68
  }
}
```

### B. AI Diagnostic Contract (AI/ML Processor -> MQTT Broker -> Backend)
* **Topic:** `honeychain/hive/processed`
```json
{
  "device_id": "SIH_HIVE_MVP_01",
  "timestamp": 1725879172,
  "hive_status": {
    "risk_level": "LOW",
    "status": "HEALTHY",
    "anomaly_detected": false,
    "anomaly_score": 0.0048
  },
  "sensors": {
    "temperature_c": 34.2,
    "humidity_pct": 61.5,
    "weight_kg": 3.25,
    "acoustics_hz": 245
  },
  "analysis": {
    "temperature": { "status": "NORMAL", "value": 34.2, "reference_range": { "min": 30.0, "max": 36.0 } },
    "humidity": { "status": "NORMAL", "value": 61.5, "reference_range": { "min": 50.0, "max": 70.0 } },
    "weight": { "status": "STABLE", "trend": "STABLE", "value_kg": 3.25 },
    "acoustics": { "status": "NORMAL", "value_hz": 245 }
  },
  "alerts": [],
  "diagnostics": {
    "battery_v": 4.12,
    "wifi_rssi_dbm": -68
  }
}
```

### C. Blockchain Provenance Event Contract (Backend -> EVM Contract)
* **Smart Contract Function:** `HoneyChainProvenance.recordEvent(...)`
```solidity
recordEvent(
    string batchId,           // e.g., "CB-98234-A78B"
    string eventType,         // "HARVEST" | "COLLECTION" | "PROCESSING" | "LAB_TEST" | "PACKAGING"
    string actorId,           // e.g., "usr-collector-042"
    string dataHash,          // SHA-256 hex digest of the canonical state JSON
    string previousEventHash  // SHA-256 hash of the parent milestone
)
```

### D. Public QR Verification Contract (Backend -> Mobile App / Consumer Web)
* **Endpoint:** `GET /verify/{qr_hash}`
```json
{
  "success": true,
  "batch_id": "CB-98234-A78B",
  "product": {
    "product_name": "Pure Wild Forest Raw Honey",
    "jar_size": "500g",
    "packaging_date": "2026-09-15T10:30:00Z"
  },
  "origin": {
    "harvester_name": "Ramesh Patil",
    "apiary_region": "Mahabaleshwar Apiary Zone, MH",
    "floral_source": "Multifloral",
    "hive_code": "HC-HIVE-04"
  },
  "lab_certification": {
    "lab_name": "National Quality Testing Laboratory",
    "quality_grade": "Grade A",
    "purity_score": 98.4,
    "moisture_pct": 17.2,
    "hmf_mg_per_kg": 12.5,
    "adulteration_detected": false
  },
  "blockchain_proof": {
    "network": "Hardhat Localhost (Chain ID: 31337)",
    "contract_address": "0x5FbDB2315678afecb367f032d93F642f64180aa3",
    "transaction_count": 4,
    "verified_on_chain": true
  }
}
```
