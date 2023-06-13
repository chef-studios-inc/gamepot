import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-gas-reporter"

const config: HardhatUserConfig = {
  solidity: "0.8.20",
  gasReporter: { currency: "ETH", enabled: true }
};

export default config;
