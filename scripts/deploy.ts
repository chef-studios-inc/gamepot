import { ethers } from "hardhat";

async function main() {
  const GamePot = await ethers.getContractFactory("GamePot_ERC20");
  const gamePot = await GamePot.deploy();

  await gamePot.deployed();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
