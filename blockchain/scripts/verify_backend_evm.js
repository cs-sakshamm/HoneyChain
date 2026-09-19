/**
 * Disposable local-EVM integration check for the Python backend service.
 *
 * It creates an in-memory Ganache node, deploys the real Solidity contract
 * compiled for Paris, then passes the ephemeral account only to the Python
 * child process environment. No key, RPC endpoint, or deployed address is
 * persisted to disk.
 */
import { spawn } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import ganache from "ganache";
import solc from "solc";
import { ContractFactory, JsonRpcProvider, Wallet } from "ethers";

function compileContract() {
  const source = fs.readFileSync(path.resolve("contracts/HoneyChainProvenance.sol"), "utf8");
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
  return output.contracts["HoneyChainProvenance.sol"].HoneyChainProvenance;
}

async function main() {
  const server = ganache.server({
    chain: { chainId: 1337 },
    logging: { quiet: true },
    wallet: { totalAccounts: 1 },
  });
  await server.listen(0, "127.0.0.1");

  try {
    const port = server.address().port;
    const rpcUrl = `http://127.0.0.1:${port}`;
    const account = Object.values(server.provider.getInitialAccounts())[0];
    const provider = new JsonRpcProvider(rpcUrl);
    const signer = new Wallet(account.secretKey, provider);
    const artifact = compileContract();
    const contract = await new ContractFactory(
      artifact.abi,
      `0x${artifact.evm.bytecode.object}`,
      signer,
    ).deploy();
    await contract.waitForDeployment();

    const defaultPython = process.platform === "win32"
      ? path.resolve("..", ".test-venv", "Scripts", "python.exe")
      : "python3";
    const python = process.env.PYTHON || defaultPython;
    const backendCheck = [
      "from backend.services.blockchain_service import BlockchainService",
      "service = BlockchainService()",
      "assert service.is_connected(), 'backend did not connect to the configured contract'",
      "result = service.record_batch_event('HC-EVM-TEST-001', 'PACKAGED', 'backend-test', {'batch': 'HC-EVM-TEST-001'})",
      "assert result['success'], result",
      "events = service.get_batch_events('HC-EVM-TEST-001')",
      "assert events['success'] and len(events['events']) == 1, events",
      "assert events['events'][0]['eventType'] == 'PACKAGED', events",
      "print('Backend EVM service check passed:', result['tx_hash'])",
    ].join("; ");
    const childEnvironment = {
      ...process.env,
      BLOCKCHAIN_PROVIDER_URL: rpcUrl,
      BLOCKCHAIN_CHAIN_ID: "1337",
      BLOCKCHAIN_PRIVATE_KEY: account.secretKey,
      CONTRACT_ADDRESS: await contract.getAddress(),
    };
    const status = await new Promise((resolve, reject) => {
      const child = spawn(python, ["-c", backendCheck], {
        cwd: path.resolve(".."),
        env: childEnvironment,
        stdio: "inherit",
      });
      child.on("error", reject);
      child.on("close", resolve);
    });
    if (status !== 0) throw new Error(`Backend EVM service check exited with status ${status}.`);
  } finally {
    await server.close();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
