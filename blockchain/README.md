# HoneyChain — Blockchain & Smart Contract Provenance Layer

The `blockchain/` module anchors HoneyChain supply-chain milestones (harvest, collection, processing, lab certification, packaging) on an EVM network and exposes the verification surface consumed by the Python backend.

---

## 1. Module Overview

* **Smart contract:** `contracts/HoneyChainProvenance.sol` (Solidity `^0.8.20`, EVM target `paris`)
* **Toolchain:** Hardhat 3 — configuration and all scripts are **TypeScript** (`.ts`). Node.js ≥ 22 runs them directly (native type stripping); `tsc --noEmit` is available as a typecheck.
* **Web3 libraries:** ethers v6 (scripts) · Web3.py 8.x (backend service in `backend/services/blockchain_service.py`)
* **Local networks:** Hardhat node / Ganache at `http://127.0.0.1:8545` (chain ID 31337)
* **Testnet:** Polygon Amoy (chain ID 80002), configured via environment variables only

---

## 2. Directory Structure

```text
blockchain/
├── contracts/
│   └── HoneyChainProvenance.sol      # Provenance events + harvester verification
├── scripts/
│   ├── deploy.ts                     # Compile + deploy (ethers), env-driven
│   └── verify_backend_evm.ts         # Ephemeral local-EVM integration check of the Python backend
├── test/
│   └── provenance.test.ts            # node:test contract test (in-process ganache)
├── compile_and_deploy.ts             # Backwards-compatible entry point → scripts/deploy.ts
├── hardhat.config.ts                 # Hardhat 3 defineConfig; env-only credentials
├── tsconfig.json                     # strict, noEmit (Node runs TS directly)
├── package.json                      # scripts: node / test / test:backend-evm / deploy / typecheck
├── deployed_address.txt              # Active deployed contract address
└── REQUIREMENT.txt                   # Runtime/dependency specification
```

---

## 3. Smart Contract (`HoneyChainProvenance.sol`)

### Data structures

```solidity
struct BatchEvent {
    string batchId;             // Collection/processing batch identifier
    string eventType;           // "HARVEST" | "COLLECTION" | "PROCESSING" | "LAB_TEST" | "PACKAGING"
    string actorId;             // Authenticated user performing the event
    string dataHash;            // SHA-256 hash of the canonical event payload
    string previousEventHash;   // Hash of the previous event in the batch lineage
    uint256 timestamp;          // Block timestamp
}

struct HarvesterVerificationRecord {
    string verificationId;      // Unique verification identifier
    string harvesterId;         // Harvester account ID
    string recordHash;          // Digest of verified credentials
    string status;              // "VERIFIED" | "PENDING" | "REJECTED"
    uint256 timestamp;
}
```

### Events (Solidity events)

* `ProvenanceRecorded(batchId, eventType, actorId, dataHash, previousEventHash, timestamp)`
* `HarvesterVerified(verificationId, harvesterId, recordHash, status, timestamp)`

### Functions

| Function | Access | Purpose |
|---|---|---|
| `recordEvent(batchId, eventType, actorId, dataHash, previousEventHash)` | `onlyOwner` | Commit a supply-chain event |
| `getEvents(batchId) → BatchEvent[]` | public view | Full event history of a batch |
| `recordHarvesterVerification(verificationId, harvesterId, recordHash, status)` | `onlyOwner` | Store verification state |
| `getHarvesterVerification(verificationId) → HarvesterVerificationRecord` | public view | Read verification state |
| `isHarvesterVerified(verificationId) → bool` | public view | Existence check |

The contract **owner is the backend's deployer account**; end users never sign transactions — the FastAPI service submits events after authorizing the workflow server-side.

---

## 4. Traceability Flow

```text
HARVEST → COLLECTION → PROCESSING → LAB TEST → PACKAGING → QR VERIFICATION
```

Each stage is recorded via `recordEvent` by the backend with a SHA-256 `dataHash` of the canonical event payload, chained to the previous event's hash. Consumers scan the packaging QR (or enter the batch code) and read the full history from `GET /api/verify/{batch_id}`.

### On-chain vs off-chain

| Layer | Content |
|---|---|
| **ON-CHAIN** | Batch/event identifiers, event type, actor ID, `dataHash`, lineage hash, timestamps |
| **OFF-CHAIN** | Full event payloads, lab reports, images, personal data (PostgreSQL) |
| **HASHED** | `dataHash` = SHA-256 of the canonical event JSON; `recordHash` for credentials |

> **Principle:** the blockchain verifies authorized submissions, contract rules, and tamper-evident history. It does **not** independently prove that physical-world data entered by a participant is truthful — it proves what was submitted, when, by whom, and that it has not changed since.

---

## 5. Setup & Deployment

```bash
cd blockchain
npm install

# 1. Local node (Terminal 1)
npm run node                     # http://127.0.0.1:8545, funded dev accounts

# 2. Deploy (Terminal 2) — credentials from the environment only
export BLOCKCHAIN_PRIVATE_KEY=<dev account key>       # never commit
node scripts/deploy.ts
# or: node compile_and_deploy.ts

# The script prints the exact values to copy into backend/.env:
#   BLOCKCHAIN_PROVIDER_URL, BLOCKCHAIN_CHAIN_ID, CONTRACT_ADDRESS
```

Network configuration (`hardhat.config.ts`):

* `localhost` — `http://127.0.0.1:8545`, chain 31337
* `amoy` — `POLYGON_AMOY_RPC_URL` (default public Amoy RPC), account from `BLOCKCHAIN_PRIVATE_KEY`, chain 80002

No private key is ever hardcoded; deploy to Amoy by exporting the two variables and running the same script (RPC URL is selected via `BLOCKCHAIN_RPC_URL`/`BLOCKCHAIN_PROVIDER_URL` in `scripts/deploy.ts`).

---

## 6. Testing

```bash
npm run typecheck          # tsc --noEmit over the toolchain
npm test                   # contract test: deploy + recordEvent + getEvents (in-process ganache)
npm run test:backend-evm   # spins up ephemeral ganache, deploys, drives the REAL
                           # Python BlockchainService in a child process (PYTHON=... to
                           # point at your venv python); nothing is persisted to disk
```

Expected: typecheck passes; `# tests 1 / # pass 1`; the EVM check prints `Backend EVM service check passed: <tx hash>`.

---

## 7. Verification Flow

1. Backend persists a workflow event (collection batch, lab report, packaging) and computes its canonical SHA-256 hash.
2. Backend submits `recordEvent(...)` (owner account) and stores the tx hash/block in `BlockchainRecord`.
3. Public `GET /api/verify/{batch_id}` returns the off-chain payload **plus** on-chain proof; `scripts/verify_backend_evm.ts` regression-tests exactly this service path against a disposable chain.
