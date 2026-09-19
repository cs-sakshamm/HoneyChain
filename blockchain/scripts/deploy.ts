import "dotenv/config"; // loads blockchain/.env (never committed); must stay first
import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import solc from "solc";
import {
  ContractFactory,
  HDNodeWallet,
  JsonRpcProvider,
  Mnemonic,
  Wallet,
} from "ethers";

/**
 * Hardhat's publicly documented development mnemonic (public knowledge, not
 * a secret). Addresses derived from it identify the 20 well-known local
 * development accounts, which must never be used on a live network.
 */
const WELL_KNOWN_DEV_MNEMONIC =
  "test test test test test test test test test test test junk";

function wellKnownDevAddresses(): Set<string> {
  const mnemonic = Mnemonic.fromPhrase(WELL_KNOWN_DEV_MNEMONIC);
  const addresses = new Set<string>();
  for (let i = 0; i < 20; i += 1) {
    const wallet = HDNodeWallet.fromMnemonic(mnemonic, `m/44'/60'/0'/0/${i}`);
    addresses.add(wallet.address.toLowerCase());
  }
  return addresses;
}

function describeChain(chainId: bigint): string {
  if (chainId === 31337n || chainId === 1337n) return "local Hardhat development chain";
  if (chainId === 80002n) return "Polygon Amoy testnet";
  if (chainId === 137n) return "Polygon mainnet (LIVE, REAL FUNDS)";
  return `chain ID ${chainId}`;
}

interface SolcOutput {
  errors?: Array<{ severity: string; formattedMessage: string }>;
  contracts: Record<
    string,
    Record<string, { abi: unknown; evm: { bytecode: { object: string } } }>
  >;
}

async function main(): Promise<void> {
  const rpcUrl =
    process.env.BLOCKCHAIN_RPC_URL ||
    process.env.BLOCKCHAIN_PROVIDER_URL ||
    "http://127.0.0.1:8545";
  const privateKey = process.env.BLOCKCHAIN_PRIVATE_KEY;
  const expectedChainId = process.env.BLOCKCHAIN_CHAIN_ID;
  if (!privateKey) {
    throw new Error(
      "BLOCKCHAIN_PRIVATE_KEY is not set.\n" +
        "Create blockchain/.env (it is git-ignored and never committed) from blockchain/.env.example and set:\n" +
        "  BLOCKCHAIN_PRIVATE_KEY=<your own wallet private key for the target network>\n" +
        "  BLOCKCHAIN_RPC_URL=<network RPC URL>\n" +
        "  BLOCKCHAIN_CHAIN_ID=<expected chain id, e.g. 80002 for Polygon Amoy>\n" +
        "For local development run 'npm run node' first; never use a real funded key locally.",
    );
  }

  const sourcePath = path.resolve("contracts/HoneyChainProvenance.sol");
  const source = fs.readFileSync(sourcePath, "utf8");
  const output = JSON.parse(
    solc.compile(
      JSON.stringify({
        language: "Solidity",
        sources: { "HoneyChainProvenance.sol": { content: source } },
        settings: {
          evmVersion: "paris",
          outputSelection: { "*": { "*": ["abi", "evm.bytecode.object"] } },
        },
      }),
    ),
  ) as SolcOutput;
  const errors = (output.errors ?? []).filter(
    (item) => item.severity === "error",
  );
  if (errors.length) {
    throw new Error(errors.map((item) => item.formattedMessage).join("\n"));
  }

  const contractData = output.contracts["HoneyChainProvenance.sol"].HoneyChainProvenance;
  const provider = new JsonRpcProvider(rpcUrl);
  const network = await provider.getNetwork();
  if (expectedChainId && network.chainId !== BigInt(expectedChainId)) {
    throw new Error(
      `RPC chain ID ${network.chainId} does not match BLOCKCHAIN_CHAIN_ID=${expectedChainId}`,
    );
  }
  const wallet = new Wallet(privateKey, provider);
  // Network safety: refuse to send transactions from publicly known
  // development accounts to any non-local chain. This fixes the root cause
  // of Hardhat's "funds WILL BE LOST" warning instead of suppressing it.
  if (network.chainId !== 31337n && network.chainId !== 1337n) {
    if (wellKnownDevAddresses().has(wallet.address.toLowerCase())) {
      throw new Error(
        `Refusing to deploy the well-known Hardhat development account ${wallet.address} to ${describeChain(network.chainId)}.\n` +
          "Funds sent from publicly known development accounts on a live network WILL BE LOST.\n" +
          "Generate a dedicated wallet and put its private key in the git-ignored blockchain/.env file.",
      );
    }
    if (network.chainId === 137n) {
      console.warn(
        `WARNING: deploying to Polygon MAINNET from ${wallet.address}. ` +
          "Verify the contract, parameters, and gas costs before continuing.",
      );
    }
  }
  const factory = new ContractFactory(
    contractData.abi as never,
    `0x${contractData.evm.bytecode.object}`,
    wallet,
  );
  const contract = await factory.deploy();
  await contract.waitForDeployment();
  const address = await contract.getAddress();
  console.log(`HoneyChainProvenance deployed to: ${address} (chain ID ${network.chainId})`);
  console.log(`Set these backend/.env values, then restart the backend:`);
  console.log(`BLOCKCHAIN_PROVIDER_URL=${rpcUrl}`);
  console.log(`BLOCKCHAIN_CHAIN_ID=${network.chainId}`);
  console.log(`CONTRACT_ADDRESS=${address}`);
}

main().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
