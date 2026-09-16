"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.blockchainService = void 0;
const ethers_1 = require("ethers");
const crypto = __importStar(require("crypto"));
// Blockchain configuration
const PRIVATE_KEY = process.env.BLOCKCHAIN_PRIVATE_KEY || '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80'; // Default Hardhat Account 0
const PROVIDER_URL = process.env.BLOCKCHAIN_PROVIDER_URL || 'http://127.0.0.1:8545';
const CONTRACT_ADDRESS = process.env.CONTRACT_ADDRESS || '0x5FbDB2315678afecb367f032d93F642f64180aa3';
const NETWORK_NAME = process.env.BLOCKCHAIN_NETWORK_NAME || 'Hardhat Localhost (Chain ID: 31337)';
const contractAbi = [
    "function recordEvent(string memory batchId, string memory eventType, string memory actorId, string memory dataHash, string memory previousEventHash) public",
    "function getEvents(string memory batchId) public view returns (tuple(string batchId, string eventType, string actorId, string dataHash, string previousEventHash, uint256 timestamp)[])",
    "function recordHarvesterVerification(string memory verificationId, string memory harvesterId, string memory recordHash, string memory status) public",
    "function getHarvesterVerification(string memory verificationId) public view returns (tuple(string verificationId, string harvesterId, string recordHash, string status, uint256 timestamp))",
    "function isHarvesterVerified(string memory verificationId) public view returns (bool)",
    "event ProvenanceRecorded(string indexed batchId, string eventType, string actorId, string dataHash, string previousEventHash, uint256 timestamp)",
    "event HarvesterVerified(string indexed verificationId, string indexed harvesterId, string recordHash, string status, uint256 timestamp)"
];
class BlockchainService {
    constructor() {
        this.provider = new ethers_1.ethers.JsonRpcProvider(PROVIDER_URL, undefined, { staticNetwork: true });
        this.wallet = new ethers_1.ethers.Wallet(PRIVATE_KEY, this.provider);
        this.contract = new ethers_1.ethers.Contract(CONTRACT_ADDRESS, contractAbi, this.wallet);
    }
    /**
     * Check if blockchain node is reachable
     */
    checkConnection() {
        return __awaiter(this, void 0, void 0, function* () {
            try {
                yield this.provider.getBlockNumber();
                return true;
            }
            catch (_a) {
                return false;
            }
        });
    }
    /**
     * Record Harvester Verification on blockchain
     */
    recordHarvesterVerificationOnChain(verificationId_1, harvesterId_1, recordHash_1) {
        return __awaiter(this, arguments, void 0, function* (verificationId, harvesterId, recordHash, status = 'VERIFIED') {
            try {
                const isOnline = yield this.checkConnection();
                if (!isOnline) {
                    console.warn(`[Blockchain] Node at ${PROVIDER_URL} is unreachable. Recording tamper-evident hash off-chain.`);
                    return {
                        success: false,
                        isOffline: true,
                        network: `${NETWORK_NAME} (Offline - Ledger Ready)`,
                        error: 'Blockchain node is currently unreachable. Verification hash recorded with tamper-evidence for node sync.'
                    };
                }
                // Execute transaction
                const tx = yield this.contract.recordHarvesterVerification(verificationId, harvesterId, recordHash, status);
                const receipt = yield tx.wait();
                return {
                    success: true,
                    txHash: receipt.hash,
                    blockNumber: receipt.blockNumber,
                    network: NETWORK_NAME
                };
            }
            catch (error) {
                console.error('[Blockchain] Error recording harvester verification:', (error === null || error === void 0 ? void 0 : error.message) || error);
                return {
                    success: false,
                    network: NETWORK_NAME,
                    error: (error === null || error === void 0 ? void 0 : error.message) || String(error)
                };
            }
        });
    }
    /**
     * Query Harvester Verification from blockchain
     */
    getHarvesterVerificationOnChain(verificationId) {
        return __awaiter(this, void 0, void 0, function* () {
            try {
                const isOnline = yield this.checkConnection();
                if (!isOnline) {
                    return { found: false, error: 'Blockchain node is offline' };
                }
                const raw = yield this.contract.getHarvesterVerification(verificationId);
                if (!raw || !raw[0] || raw[0] === '') {
                    return { found: false };
                }
                return {
                    found: true,
                    record: {
                        verificationId: raw[0],
                        harvesterId: raw[1],
                        recordHash: raw[2],
                        status: raw[3],
                        timestamp: Number(raw[4])
                    }
                };
            }
            catch (error) {
                return { found: false, error: (error === null || error === void 0 ? void 0 : error.message) || String(error) };
            }
        });
    }
    /**
     * Compute cryptographic SHA-256 hash of canonical verification payload
     */
    computeVerificationHash(payload) {
        const sortedKeys = Object.keys(payload).sort();
        const canonicalObj = {};
        for (const key of sortedKeys) {
            canonicalObj[key] = payload[key];
        }
        const jsonString = JSON.stringify(canonicalObj);
        return crypto.createHash('sha256').update(jsonString).digest('hex');
    }
    /**
     * Record Batch Lifecycle Event on blockchain
     */
    recordBatchEventOnChain(batchId_1, eventType_1, actorId_1, dataObj_1) {
        return __awaiter(this, arguments, void 0, function* (batchId, eventType, actorId, dataObj, previousEventHash = '') {
            const dataString = typeof dataObj === 'string' ? dataObj : JSON.stringify(dataObj);
            const dataHash = crypto.createHash('sha256').update(dataString).digest('hex');
            try {
                const isOnline = yield this.checkConnection();
                if (!isOnline) {
                    return {
                        success: false,
                        isOffline: true,
                        dataHash,
                        network: NETWORK_NAME,
                        status: 'PENDING',
                        error: 'Blockchain node is currently unreachable. Status: Blockchain Pending'
                    };
                }
                const tx = yield this.contract.recordEvent(batchId, eventType, actorId, dataHash, previousEventHash);
                const receipt = yield tx.wait();
                return {
                    success: true,
                    txHash: receipt.hash,
                    blockNumber: receipt.blockNumber,
                    dataHash,
                    network: NETWORK_NAME,
                    status: 'CONFIRMED'
                };
            }
            catch (error) {
                console.warn(`[Blockchain] Could not commit tx on chain for ${eventType}:`, (error === null || error === void 0 ? void 0 : error.message) || error);
                return {
                    success: false,
                    dataHash,
                    network: NETWORK_NAME,
                    status: 'PENDING',
                    error: (error === null || error === void 0 ? void 0 : error.message) || String(error)
                };
            }
        });
    }
    /**
     * Get all on-chain events for a batch
     */
    getBatchEventsOnChain(batchId) {
        return __awaiter(this, void 0, void 0, function* () {
            try {
                const isOnline = yield this.checkConnection();
                if (!isOnline)
                    return [];
                const events = yield this.contract.getEvents(batchId);
                return events.map((e) => ({
                    batchId: e.batchId,
                    eventType: e.eventType,
                    actorId: e.actorId,
                    dataHash: e.dataHash,
                    previousEventHash: e.previousEventHash,
                    timestamp: Number(e.timestamp)
                }));
            }
            catch (_a) {
                return [];
            }
        });
    }
    get contractAddress() {
        return CONTRACT_ADDRESS;
    }
    get networkName() {
        return NETWORK_NAME;
    }
}
exports.blockchainService = new BlockchainService();
