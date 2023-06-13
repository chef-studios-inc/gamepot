import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect, util } from "chai";
import { ethers } from "hardhat";
import { BigNumber, utils } from "ethers";
import { GamePot__factory } from "./../typechain-types";
import exp from "constants";
import {expectThrow, expectNoThrow} from "./utils/utils";
import { PrizePoolRoyaltySplitStruct, PrizePoolSettingsStruct } from "./../typechain-types/contracts/PrizePool/PrizePool";

describe("GamePot", function () {
  async function deployPrizePool() {
    // Contracts are deployed using the first signer/account by default
    const [deployer, ...users] = await ethers.getSigners();
    const GamePot: GamePot__factory = await ethers.getContractFactory("GamePot");
    const gamePot = await GamePot.deploy();
    const ERC20 = await ethers.getContractFactory("TestERC20");
    const currency1 = await ERC20.deploy();
    const currency2 = await ERC20.deploy();

    return { gamePot, users, deployer, currency1, currency2 };
  }

  it("e2e", async function () {
    const { gamePot, currency1, currency2, users, deployer } = await loadFixture(deployPrizePool);
    const players = users.slice(3, 8);

    var game_id = await gamePot.createGame(currency1.address, [3,2,1], ethers.utils.parseEther("1"), ethers.utils.parseEther("0"));

    let throws = false;
    try {
      var gp0 = gamePot.connect(users[0]);
      await gp0.createGame(currency1.address, [3,2,1], ethers.utils.parseEther("1"), ethers.utils.parseEther("0"));
    } catch(err) {
      throws = true;
    }
    expect(throws).to.be.true;
  });
});