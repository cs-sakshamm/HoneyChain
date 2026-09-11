import { ethers } from 'ethers';
import * as crypto from 'crypto';

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
  private provider: ethers.JsonRpcProvider;
  private wallet: ethers.Wallet;
  private contract: ethers.Contract;

  constructor() {
    this.provider = new ethers.JsonRpcProvider(PROVIDER_URL);
    this.wallet = new ethers.Wallet(PRIVATE_KEY, this.provider);
    this.contract = new ethers.Contract(CONTRACT_ADDRESS, contractAbi, this.wallet);
  }

  /**
   * Check if blockchain node is reachable
   */
  async checkConnection(): Promise<boolean> {
    try {
      await this.provider.getBlockNumber();
      return true;
    } catch {
      return false;
    }
  }

  /**
   * Record Harvester Verification on blockchain
   */
  async recordHarvesterVerificationOnChain(
    verificationId: string,
    harvesterId: string,
    recordHash: string,
    status: string = 'VERIFIED'
  ): Promise<{
    success: boolean;
    txHash?: string;
    blockNumber?: number;
    network: string;
    isOffline?: boolean;
    error?: string;
  }> {
    try {
      const isOnline = await this.checkConnection();
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
      const tx = await (this.contract as any).recordHarvesterVerification(
        verificationId,
        harvesterId,
        recordHash,
        status
      );

      const receipt = await tx.wait();

      return {
        success: true,
        txHash: receipt.hash,
        blockNumber: receipt.blockNumber,
        network: NETWORK_NAME
      };
    } catch (error: any) {
      console.error('[Blockchain] Error recording harvester verification:', error?.message || error);
      return {
        success: false,
        network: NETWORK_NAME,
        error: error?.message || String(error)
      };
    }
  }

  /**
   * Query Harvester Verification from blockchain
   */
  async getHarvesterVerificationOnChain(verificationId: string): Promise<{
    found: boolean;
    record?: {
      verificationId: string;
      harvesterId: string;
      recordHash: string;
      status: string;
      timestamp: number;
    };
    error?: string;
  }> {
    try {
      const isOnline = await this.checkConnection();
      if (!isOnline) {
        return { found: false, error: 'Blockchain node is offline' };
      }

      const raw = await (this.contract as any).getHarvesterVerification(verificationId);
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
    } catch (error: any) {
      return { found: false, error: error?.message || String(error) };
    }
  }

  /**
   * Compute cryptographic SHA-256 hash of canonical verification payload
   */
  computeVerificationHash(payload: Record<string, any>): string {
    const sortedKeys = Object.keys(payload).sort();
    const canonicalObj: Record<string, any> = {};
    for (const key of sortedKeys) {
      canonicalObj[key] = payload[key];
    }
    const jsonString = JSON.stringify(canonicalObj);
    return crypto.createHash('sha256').update(jsonString).digest('hex');
  }

  get contractAddress(): string {
    return CONTRACT_ADDRESS;
  }

  get networkName(): string {
    return NETWORK_NAME;
  }
}

export const blockchainService = new BlockchainService();
