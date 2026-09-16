# HoneyChain — Blockchain & Smart Contract Provenance Layer

The `blockchain` module implements the decentralized trust, auditability, and immutability layer of HoneyChain. It anchors every critical supply chain milestone (harvest, collection, processing, laboratory quality certification, packaging) onto an Ethereum Virtual Machine (EVM)-compatible blockchain network.

---

## 1. Module Overview

* **Smart Contract:** `contracts/HoneyChainProvenance.sol` (Solidity `^0.8.20`)
* **Development Framework:** Hardhat & Ganache
* **Web3 Libraries:** Ethers.js v6 (deployment and Node scripts) & Web3.py v6 (FastAPI backend integration)
* **Default Network:** Local Ganache / Hardhat Node (`http://127.0.0.1:8545`)

---

## 2. Directory Structure

```text
blockchain/
├── contracts/
│   └── HoneyChainProvenance.sol  # Solidity smart contract for provenance events & harvester KYC
├── scripts/
│   └── deploy.js                 # Deployment script using ethers.js
├── compile_and_deploy.js         # Standalone compilation and deployment script
├── deployed_address.txt          # Stores the active deployed contract address
├── hardhat.config.js             # Hardhat network configuration and compiler settings
├── package.json                  # Hardhat, ethers, and ganache dependencies
├── .gitignore                    # Git rules ignoring artifacts, cache, and node_modules
├── README.md                     # Blockchain documentation (this file)
└── REQUIREMENT.txt               # Node & Solidity runtime dependencies
```

---

## 3. Smart Contract Architecture (`HoneyChainProvenance.sol`)

### Data Structures

#### `BatchEvent`
Records an atomic supply chain transition for a honey batch:
```solidity
struct BatchEvent {
    string batchId;           // Identifier of the collection/processing batch
    string eventType;         // Event type: "HARVEST", "COLLECTION", "PROCESSING", "LAB_TEST", "PACKAGING"
    string actorId;           // ID of the authenticated user performing the event
    string dataHash;          // SHA-256 hash of the complete event payload
    string previousEventHash;  // Hash of the prior event in the batch lineage
    uint256 timestamp;        // Block timestamp
}
```

#### `HarvesterVerificationRecord`
Anchors harvester identity verification and KYC state:
```solidity
struct HarvesterVerificationRecord {
    string verificationId;    // Unique verification identifier
    string harvesterId;       // Harvester account ID
    string recordHash;        // Cryptographic digest of verified government/apiary credentials
    string status;            // "VERIFIED", "PENDING", or "REJECTED"
    uint256 timestamp;        // Verification block timestamp
}
```

### Events

* `event ProvenanceRecorded(string indexed batchId, string eventType, string actorId, string dataHash, string previousEventHash, uint256 timestamp)`
* `event HarvesterVerified(string indexed verificationId, string indexed harvesterId, string recordHash, string status, uint256 timestamp)`

### Key Functions

* `recordEvent(batchId, eventType, actorId, dataHash, previousEventHash)`: Commits a new supply chain event to storage (restricted to `onlyOwner`).
* `getEvents(batchId) returns (BatchEvent[])`: Public view returning the complete event history of a batch.
* `recordHarvesterVerification(verificationId, harvesterId, recordHash, status)`: Stores verified harvester identity hashes.
* `getHarvesterVerification(verificationId) returns (HarvesterVerificationRecord)`: Fetches harvester verification state.
* `isHarvesterVerified(verificationId) returns (bool)`: Quick boolean check for verification existence.

---

## 4. Setup & Deployment Instructions

### Prerequisites
* Node.js >= 18.0.0 LTS
* npm >= 9.0.0

### Step 1: Install Dependencies

```bash
cd blockchain
npm install
```

### Step 2: Start Local Blockchain Node

In Terminal 1, run Hardhat's local JSON-RPC node:

```bash
npx hardhat node
```

This starts a local EVM network listening on `http://127.0.0.1:8545` with 20 funded test accounts.

Alternatively, launch Ganache:

```bash
npx ganache --port 8545
```

### Step 3: Compile and Deploy Contract

In Terminal 2, run the deployment script:

```bash
node scripts/deploy.js
```

Or run the all-in-one deployer:

```bash
node compile_and_deploy.js
```

The script:
1. Compiles `contracts/HoneyChainProvenance.sol`.
2. Deploys the contract to the local node.
3. Prints the deployed contract address.
4. Writes the address to `blockchain/deployed_address.txt`.

Example output:
```text
HoneyChainProvenance deployed to: 0x5FbDB2315678afecb367f032d93F642f64180aa3
```

---

## 5. Backend Integration

The backend interacts with the smart contract using `backend/services/blockchain_service.py` via Web3.py.

### Required Environment Variables in `backend/.env`

```env
BLOCKCHAIN_RPC_URL="http://127.0.0.1:8545"
CONTRACT_ADDRESS="0x5FbDB2315678afecb367f032d93F642f64180aa3"
BLOCKCHAIN_PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
```

Whenever a collection batch, lab certification, or packaging event occurs, the backend:
1. Computes `dataHash = sha256(canonical_event_json)`.
2. Obtains `previousEventHash` from the batch lineage.
3. Submits an authenticated transaction executing `recordEvent()`.
4. Saves the resulting transaction hash to the database `blockchain_records` table.
