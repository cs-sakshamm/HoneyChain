import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import solc from "solc";
import { ContractFactory, JsonRpcProvider, Wallet } from "ethers";

async function main() {
  const rpcUrl = process.env.BLOCKCHAIN_RPC_URL || process.env.BLOCKCHAIN_PROVIDER_URL || "http://127.0.0.1:8545";
  const privateKey = process.env.BLOCKCHAIN_PRIVATE_KEY;
  const expectedChainId = process.env.BLOCKCHAIN_CHAIN_ID;
  if (!privateKey) {
    throw new Error("BLOCKCHAIN_PRIVATE_KEY is required. Use a local development account only in an untracked .env file.");
  }

  const sourcePath = path.resolve("contracts/HoneyChainProvenance.sol");
  const source = fs.readFileSync(sourcePath, "utf8");
  const output = JSON.parse(solc.compile(JSON.stringify({
    language: "Solidity",
    sources: { "HoneyChainProvenance.sol": { content: source } },
    settings: {
      evmVersion: "paris",
      outputSelection: { "*": { "*": ["abi", "evm.bytecode.object"] } },
    },
  })));
  const errors = (output.errors || []).filter((item) => item.severity === "error");
  if (errors.length) throw new Error(errors.map((item) => item.formattedMessage).join("\n"));

  const contractData = output.contracts["HoneyChainProvenance.sol"].HoneyChainProvenance;
  const provider = new JsonRpcProvider(rpcUrl);
  const network = await provider.getNetwork();
  if (expectedChainId && network.chainId !== BigInt(expectedChainId)) {
    throw new Error(`RPC chain ID ${network.chainId} does not match BLOCKCHAIN_CHAIN_ID=${expectedChainId}`);
  }
  const wallet = new Wallet(privateKey, provider);
  const factory = new ContractFactory(contractData.abi, `0x${contractData.evm.bytecode.object}`, wallet);
  const contract = await factory.deploy();
  await contract.waitForDeployment();
  const address = await contract.getAddress();
  console.log(`HoneyChainProvenance deployed to: ${address} (chain ID ${network.chainId})`);
  console.log(`Set these backend/.env values, then restart the backend:`);
  console.log(`BLOCKCHAIN_PROVIDER_URL=${rpcUrl}`);
  console.log(`BLOCKCHAIN_CHAIN_ID=${network.chainId}`);
  console.log(`CONTRACT_ADDRESS=${address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
