# HoneyChain — System Documentation & Architectural Blueprints

The `docs` module houses the comprehensive system architecture documentation, design specifications, workflow sequence diagrams, and cross-subsystem integration blueprints for the HoneyChain platform.

---

## 1. Documentation Index

| Document / Topic | Description | Target Audience |
| :--- | :--- | :--- |
| **System Overview & Architecture** | High-level topology connecting IoT, AI, Backend, Blockchain, and Mobile clients | All Developers / Architects |
| **End-to-End Honey Lifecycle** | Step-by-step state machine from apiary harvest to retail jar purchase | Product Managers / Domain Experts |
| **IoT Sensor Specifications** | ESP32 pinouts, sampling frequencies, and MQTT data schemas | Embedded / Firmware Engineers |
| **AI/ML Subsystem Architecture** | Isolation Forest baseline, rolling window feature engineering, and risk engine rules | AI / Data Science Engineers |
| **Backend REST & WebSocket APIs** | FastAPI endpoint contracts, SQLAlchemy database models, and real-time alerts | Backend / Integration Engineers |
| **Smart Contract & Provenance** | `HoneyChainProvenance.sol` data structures, event logging, and cryptographic verification | Web3 / Blockchain Engineers |
| **Mobile App Dashboards** | Role-based navigation for Harvesters, Collectors, Labs, Packaging, and Public Consumers | Mobile / UI/UX Engineers |

---

## 2. End-to-End Supply Chain Flowchart

```mermaid
flowchart TD
    subgraph Apiary ["1. Apiary (Origin)"]
        H[Harvester / Beekeeper] -->|Logs Harvest| HV[Hive]
        ESP[ESP32 Edge Node] -->|Telemetry MQTT| BRK[Mosquitto Broker]
        BRK -->|honeychain/hive/telemetry| AI[AI/ML Engine]
        AI -->|honeychain/hive/processed| BE[FastAPI Backend]
    end

    subgraph Collection ["2. Collection & Aggregation"]
        H -->|Submits Request| CR[Collection Request]
        CR -->|Weight & Moisture Verified| CC[Collection Hub]
        CC -->|Aggregates into| CB[Collection Batch]
        CB -->|Anchor Hash| BC[(Blockchain Ledger)]
    end

    subgraph Processing ["3. Processing Facility"]
        CB -->|Filtration & Refinement| PB[Processing Batch]
        PB -->|Anchor Hash| BC
    end

    subgraph Laboratory ["4. Quality Assurance & Testing"]
        PB -->|Sample Submission| LAB[Accredited Lab]
        LAB -->|Moisture, Pollen, HMF, Purity| LR[Lab Report]
        LR -->|Grade A Certificate Hash| BC
    end

    subgraph Retail ["5. Packaging & Consumer Verification"]
        LR -->|Approved Batch| PKG[Packaging Facility]
        PKG -->|Serialized Jars| QR[Traceability QR Code]
        QR -->|Anchor Hash| BC
        QR -->|Scanned by| CON[Public Consumer]
        CON -->|Verify Provenance| BE
        BE -->|Fetch Events| BC
    end
```

---

## 3. Telemetry Stream Sequence Diagram

```mermaid
sequenceDiagram
    autonumber
    participant ESP as ESP32 Hive Node
    participant MOS as Mosquitto Broker
    participant AI as AI Isolation Forest
    participant BE as FastAPI Backend
    participant DB as Supabase PostgreSQL
    participant WS as Flutter Mobile App

    ESP->>MOS: PUBLISH honeychain/hive/telemetry (weight, temp, humidity, acoustics)
    MOS->>AI: DELIVER raw telemetry packet
    MOS->>BE: DELIVER raw telemetry packet
    BE->>DB: INSERT INTO hive_telemetry
    AI->>AI: Compute 1h deltas, 6h rolling stats, 24h weight delta
    AI->>AI: Predict anomaly score & evaluate reference rules
    AI->>MOS: PUBLISH honeychain/hive/processed (risk_level, diagnostics, alerts)
    MOS->>BE: DELIVER processed payload
    BE->>DB: INSERT INTO hive_ai_analysis
    alt Risk Level == HIGH or Anomaly Detected
        BE->>DB: INSERT INTO hive_alerts
        BE->>WS: BROADCAST WebSocket alert packet (/ws/telemetry)
        WS->>WS: Display audio & visual banner to Beekeeper
    end
```

---

## 4. Documentation Standards

* **Format:** GitHub Flavored Markdown (`GFM`)
* **Diagrams:** Mermaid.js fenced code blocks (`mermaid`)
* **Mathematical Notation:** KaTeX / LaTeX format (`$math$`)
* **Integrity Guarantee:** Never edit, format, or modify files inside `ai_ml/`. It is strictly read-only.
