import hre from 'hardhat';

async function main() {
  const HoneyChainProvenance = await hre.ethers.getContractFactory('HoneyChainProvenance');
  const contract = await HoneyChainProvenance.deploy();
  await contract.waitForDeployment();
  const address = await contract.getAddress();
  console.log(`HoneyChainProvenance deployed to: ${address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
