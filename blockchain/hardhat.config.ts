import { defineConfig } from "hardhat/config";

/**
 * Hardhat 3 configuration. RPC credentials are read exclusively from the
 * environment; no key is ever hardcoded here. Expressions are identical to
 * the previous plain-object export:
 *  - localhost network stays hardcoded (dev-only endpoint);
 *  - amoy keeps the same env fallbacks for RPC URL / deployer key.
 */
const amoyRpcUrl = process.env.POLYGON_AMOY_RPC_URL || "https://rpc-amoy.polygon.technology";
const amoyPrivateKey = process.env.BLOCKCHAIN_PRIVATE_KEY;

const hardhatConfig = defineConfig({
  solidity: "0.8.20",
  networks: {
    localhost: {
      type: "http",
      url: "http://127.0.0.1:8545",
      chainId: 31337,
    },
    amoy: {
      type: "http",
      url: amoyRpcUrl,
      accounts: amoyPrivateKey ? [amoyPrivateKey] : [],
      chainId: 80002,
    },
  },
});

export default hardhatConfig;
