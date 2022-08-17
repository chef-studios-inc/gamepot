import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";
import { BigNumber } from "ethers";
import { GameState, GameState__factory } from "../../typechain-types";
import exp from "constants";
import {expectThrow, expectNoThrow} from "../utils/utils";

describe("PrizePool", function () {
  async function deployPrizePool() {
    // Contracts are deployed using the first signer/account by default
    const users = await ethers.getSigners();
    const PrizePool = await ethers.getContractFactory("PrizePool");
    const prizePool = await PrizePool.deploy();
    const ERC20 = await ethers.getContractFactory("ERC20");
    const currency1 = await ERC20.deploy("currency_1", "CUR1");
    const currency2 = await ERC20.deploy("currency_2", "CUR2");

    return { prizePool, users, currency1, currency2 };
  }

  describe("Create a pool", async function () {
    it("Should be able to create pools", async function () {
      const { prizePool, currency1, currency2 } = await loadFixture(deployPrizePool);
      await expectNoThrow(prizePool.createPool(123, currency1.address), "should be able to create a pool");
    });
  });

  describe("Pool payouts", async function () {
  });

  describe("Pool refunds", async function () {
  });

});