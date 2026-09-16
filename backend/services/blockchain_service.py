"""
Blockchain provenance service using Web3.py.
Interacts with the HoneyChainProvenance smart contract with offline-safe tamper-evident hashing.
"""
from __future__ import annotations

import os
import json
import hashlib
import logging
from typing import Dict, Any, Optional

try:
    from web3 import Web3
except ImportError:
    Web3 = None

logger = logging.getLogger("BlockchainService")

# Configuration
RPC_URL = os.getenv("BLOCKCHAIN_PROVIDER_URL", os.getenv("POLYGON_AMOY_RPC_URL", "http://127.0.0.1:8545"))
PRIVATE_KEY = os.getenv("BLOCKCHAIN_PRIVATE_KEY", "")
CONTRACT_ADDRESS = os.getenv("CONTRACT_ADDRESS", "")
NETWORK_NAME = os.getenv("BLOCKCHAIN_NETWORK_NAME", "Polygon Amoy (Chain ID: 80002)" if "amoy" in RPC_URL else "Hardhat Localhost (Chain ID: 31337)")

CONTRACT_ABI = [
    {
        "inputs": [
            {"internalType": "string", "name": "batchId", "type": "string"},
            {"internalType": "string", "name": "eventType", "type": "string"},
            {"internalType": "string", "name": "actorId", "type": "string"},
            {"internalType": "string", "name": "dataHash", "type": "string"},
            {"internalType": "string", "name": "previousEventHash", "type": "string"},
        ],
        "name": "recordEvent",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function",
    },
    {
        "inputs": [{"internalType": "string", "name": "batchId", "type": "string"}],
        "name": "getEvents",
        "outputs": [
            {
                "components": [
                    {"internalType": "string", "name": "batchId", "type": "string"},
                    {"internalType": "string", "name": "eventType", "type": "string"},
                    {"internalType": "string", "name": "actorId", "type": "string"},
                    {"internalType": "string", "name": "dataHash", "type": "string"},
                    {"internalType": "string", "name": "previousEventHash", "type": "string"},
                    {"internalType": "uint256", "name": "timestamp", "type": "uint256"},
                ],
                "internalType": "struct HoneyChainProvenance.BatchEvent[]",
                "name": "",
                "type": "tuple[]",
            }
        ],
        "stateMutability": "view",
        "type": "function",
    },
]


class BlockchainService:
    def __init__(self):
        self.rpc_url = RPC_URL
        self.contract_address = CONTRACT_ADDRESS
        self.network = NETWORK_NAME
        self.w3 = None
        self.contract = None
        self.account = None

        if Web3 and PRIVATE_KEY and CONTRACT_ADDRESS:
            try:
                self.w3 = Web3(Web3.HTTPProvider(self.rpc_url, request_kwargs={"timeout": 2.0}))
                if self.w3.is_connected():
                    self.account = self.w3.eth.account.from_key(PRIVATE_KEY)
                    checksum_address = Web3.to_checksum_address(self.contract_address)
                    self.contract = self.w3.eth.contract(address=checksum_address, abi=CONTRACT_ABI)
                    logger.info(f"Connected to blockchain node at {self.rpc_url}")
            except Exception as e:
                logger.warning(f"Blockchain initialization notice: {e}")
        else:
            logger.info("Blockchain running in offline-safe tamper-evident hashing mode.")

    def is_connected(self) -> bool:
        try:
            return self.w3 is not None and self.w3.is_connected()
        except Exception:
            return False

    def compute_hash(self, data: Any) -> str:
        serialized = json.dumps(data, sort_keys=True, default=str)
        return hashlib.sha256(serialized.encode("utf-8")).hexdigest()

    def record_batch_event(
        self,
        batch_id: str,
        event_type: str,
        actor_id: str,
        payload: Dict[str, Any],
        previous_event_hash: str = "",
    ) -> Dict[str, Any]:
        data_hash = self.compute_hash(payload)

        if not self.is_connected():
            logger.info(f"[Blockchain Offline] Recording tamper-evident hash for {batch_id} ({event_type}): {data_hash[:16]}...")
            return {
                "success": False,
                "status": "PENDING",
                "data_hash": data_hash,
                "tx_hash": None,
                "block_number": None,
                "network": f"{self.network} (Offline - Ledger Ready)",
                "error": "Blockchain node offline. Tamper-evident hash logged for reconciliation.",
            }

        try:
            tx = self.contract.functions.recordEvent(
                batch_id,
                event_type,
                actor_id,
                data_hash,
                previous_event_hash,
            ).build_transaction({
                "from": self.account.address,
                "nonce": self.w3.eth.get_transaction_count(self.account.address),
                "gas": 300000,
                "gasPrice": self.w3.eth.gas_price,
            })

            signed_tx = self.w3.eth.account.sign_transaction(tx, private_key=PRIVATE_KEY)
            tx_hash = self.w3.eth.send_raw_transaction(signed_tx.rawTransaction)
            receipt = self.w3.eth.wait_for_transaction_receipt(tx_hash, timeout=10)

            tx_hex = self.w3.to_hex(tx_hash)
            logger.info(f"[Blockchain] Event {event_type} committed on-chain: {tx_hex}")
            return {
                "success": True,
                "status": "CONFIRMED",
                "data_hash": data_hash,
                "tx_hash": tx_hex,
                "block_number": receipt.blockNumber,
                "network": self.network,
                "error": None,
            }
        except Exception as err:
            logger.error(f"[Blockchain Error] Failed to submit transaction: {err}")
            return {
                "success": False,
                "status": "FAILED",
                "data_hash": data_hash,
                "tx_hash": None,
                "block_number": None,
                "network": self.network,
                "error": str(err),
            }


blockchain_service = BlockchainService()
