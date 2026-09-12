import fs from 'fs';
import solc from 'solc';
import { ethers } from 'ethers';

const source = fs.readFileSync('contracts/HoneyChainProvenance.sol', 'utf8');

const input = {
  language: 'Solidity',
  sources: {
    'HoneyChainProvenance.sol': {
      content: source,
    },
  },
  settings: {
    outputSelection: {
      '*': {
        '*': ['*'],
      },
    },
  },
};

console.log("Compiling contract...");
const output = JSON.parse(solc.compile(JSON.stringify(input)));

if (output.errors) {
  output.errors.forEach(err => console.error(err.formattedMessage));
}

const contractData = output.contracts['HoneyChainProvenance.sol'].HoneyChainProvenance;
const abi = contractData.abi;
const bytecode = contractData.evm.bytecode.object;

console.log("Deploying contract...");
const PROVIDER_URL = 'http://127.0.0.1:8545';
const PRIVATE_KEY = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';

const provider = new ethers.JsonRpcProvider(PROVIDER_URL);
const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

const factory = new ethers.ContractFactory(abi, bytecode, wallet);
async function deploy() {
  try {
    const contract = await factory.deploy();
    await contract.waitForDeployment();
    console.log("Contract deployed to:", contract.target);
    fs.writeFileSync('deployed_address.txt', contract.target);
  } catch (err) {
    console.error("Deploy error:", err);
  }
}
deploy();
