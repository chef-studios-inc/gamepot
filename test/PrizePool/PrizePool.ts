import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";
import { BigNumber, utils } from "ethers";
import { GameState, GameState__factory } from "../../typechain-types";
import exp from "constants";
import {expectThrow, expectNoThrow} from "../utils/utils";
import { prizePool } from "../../typechain-types/contracts";
import { PrizePoolRoyaltySplitStruct, PrizePoolSettingsStruct } from "../../typechain-types/contracts/PrizePool/PrizePool";

describe("PrizePool", function () {
  async function deployPrizePool() {
    // Contracts are deployed using the first signer/account by default
    const [deployer, royaltyRecipient10, royaltyRecipient90, ...users] = await ethers.getSigners();
    const PrizePool = await ethers.getContractFactory("PrizePool");
    const prizePool = await PrizePool.deploy();
    const ERC20 = await ethers.getContractFactory("TestERC20");
    const currency1 = await ERC20.deploy();
    const currency2 = await ERC20.deploy();
    const royaltySplits: PrizePoolRoyaltySplitStruct[] = [{ recipient: royaltyRecipient10.address, percentage: 10 }, { recipient: royaltyRecipient90.address, percentage: 90 }];
    const settings: PrizePoolSettingsStruct = { joinPoolPrice: utils.parseEther("1"), royaltySplits, firstPlaceMultiplier: 2, topPercentOfPlayersPaidOut: 40, totalRoyaltyPercent: 10 };

    return { prizePool, users, deployer, currency1, currency2, settings, royaltyRecipient10, royaltyRecipient90 };
  }

  describe("Create a pool", async function () {
    it("Should be able to create pools", async function () {
      const { prizePool, currency1, currency2, settings } = await loadFixture(deployPrizePool);
      await expectNoThrow(prizePool.createPool(123, currency1.address, settings), "should be able to create a pool");

      await expectThrow(prizePool.createPool(123, currency2.address, settings), "existing pool should fail");
      await expectNoThrow(prizePool.createPool(456, currency1.address, settings), "second pool should succeed");
    });
  });

  it("Should get paid out appropriately", async function () {
    const { prizePool, currency1, users, settings, royaltyRecipient10, royaltyRecipient90 } = await loadFixture(deployPrizePool);
    await prizePool.createPool(1, currency1.address, settings);

    // add credits
    for (let i = 0; i < 10; i++) {
      await currency1.transfer(users[i].address, utils.parseEther("10"));
      const user1Currency1 = await currency1.connect(users[i]);
      await user1Currency1.approve(prizePool.address, utils.parseEther("1000000000"));
      expect(await currency1.balanceOf(users[i].address)).to.eql(utils.parseEther("10"));
      await prizePool.addCredits(1, utils.parseEther("5"), users[i].address);
      expect(await currency1.balanceOf(users[i].address)).to.eql(utils.parseEther("5"));
      expect(await prizePool.getCreditBalance(1, users[i].address)).to.eq(utils.parseEther("5"));
    }

    // join pool
    for (let i = 0; i < 10; i++) {
      await prizePool.joinPrizePool(1, users[i].address);
      expect(await prizePool.getCreditBalance(1, users[i].address)).to.eq(utils.parseEther("4"));
    }

    // play game
    await prizePool.awardLeaderboard(1, users.slice(0,10).map(u => u.address));

    // royalties get paid out
    for (let i = 0; i < 10; i++) {
      expect(await prizePool.getCreditBalance(1, royaltyRecipient90.address)).to.eq(utils.parseEther("0.9"));
      expect(await prizePool.getCreditBalance(1, royaltyRecipient10.address)).to.eq(utils.parseEther("0.1"));
    }

    // make sure winner gets double 
    const winnerCredits = await prizePool.getCreditBalance(1, users[0].address);
    console.log("NEIL winner credits", winnerCredits);
    expect(winnerCredits.eq(utils.parseEther("6"))).to.be.true;
    

    // make sure winners are getting more than losers
    for(let i = 0; i < 9; i++) {
      const j = i + 1;
      const balance1 = await prizePool.getCreditBalance(1, users[i].address);
      const balance2 = await prizePool.getCreditBalance(1, users[j].address);
      console.log(balance1, i, balance2);
      expect(balance1.gte(balance2)).to.be.true;
    }
  });

  describe("Pool refunds", async function () {
  });

});