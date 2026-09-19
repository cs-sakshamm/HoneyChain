import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";
import ganache from "ganache";
import solc from "solc";
import { BrowserProvider, ContractFactory } from "ethers";

interface SolcOutput {
  errors?: Array<{ severity: string; formattedMessage: string }>;
  contracts: Record<
    string,
    Record<string, { abi: unknown; evm: { bytecode: { object: string } } }>
  >;
}

interface GanacheProvenanceEvent {
  eventType: string;
  dataHash: string;
}

/** Minimal shape of the deployed HoneyChainProvenance contract used here. */
interface GanacheProvenanceContract {
  waitForDeployment(): Promise<unknown>;
  recordEvent(
    batchId: string,
    eventType: string,
    actor: string,
    dataHash: string,
    metadata: string,
  ): Promise<{ wait(): Promise<unknown> }>;
  getEvents(batchId: string): Promise<GanacheProvenanceEvent[]>;
}

function compileContract(): { abi: unknown; evm: { bytecode: { object: string } } } {
  const source = fs.readFileSync(
    path.resolve("contracts/HoneyChainProvenance.sol"),
    "utf8",
  );
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
  assert.equal(
    errors.length,
    0,
    errors.map((item) => item.formattedMessage).join("\n"),
  );
  return output.contracts["HoneyChainProvenance.sol"].HoneyChainProvenance;
}

test("records and reads a batch provenance event", async () => {
  const artifact = compileContract();
  const provider = new BrowserProvider(
    ganache.provider({ logging: { quiet: true } }),
  );
  const signer = await provider.getSigner();
  const factory = new ContractFactory(
    artifact.abi as never,
    `0x${artifact.evm.bytecode.object}`,
    signer,
  );
  const contract = (await factory.deploy()) as unknown as GanacheProvenanceContract;
  await contract.waitForDeployment();

  await (
    await contract.recordEvent("HC-BATCH-TEST-001", "HARVEST", "beekeeper-1", "abc123", "")
  ).wait();
  const events = await contract.getEvents("HC-BATCH-TEST-001");
  assert.equal(events.length, 1);
  assert.equal(events[0].eventType, "HARVEST");
  assert.equal(events[0].dataHash, "abc123");
});
