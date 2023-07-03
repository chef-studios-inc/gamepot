import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect, use, util } from "chai";
import { ethers } from "hardhat";
import { BigNumber, parseEther, utils } from "ethers";
import { GamePot__factory } from "./../typechain-types";
import exp from "constants";
import { expectThrow, expectNoThrow } from "./utils/utils";
import { randomBytes } from "crypto";

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
    const { gamePot, currency1, users, deployer } = await loadFixture(deployPrizePool);

    const game_id = BigInt(`0x${randomBytes(32).toString('hex')}`);

    // Joe Bloe should not be able to create a game
    await expectThrow(gamePot.connect(users[0]).createGame(game_id, currency1, [3, 2, 1], [], parseEther("1"), parseEther("0")), "Only owner can create games");

    // Joe Bloe can't set royalty
    await expectThrow(gamePot.connect(users[0]).setRoyaltyPercentage(10), "Only owner can set royalty split");

    // Joe Bloe can't set admin
    await expectThrow(gamePot.connect(users[0]).setAdmin(users[1].address), "Only owner can set admin");

    // Admin can set royalty, royalty set to 10%
    await gamePot.setAdmin(users[0].address);
    await expectNoThrow(gamePot.connect(users[0]).setRoyaltyPercentage(10), "Admin can set royalty split");
    await gamePot.unsetAdmin(users[0].address);
    await expectThrow(gamePot.connect(users[0]).setRoyaltyPercentage(5), "Admin can set royalty split");


    // Add credits
    for(let i = 0; i < 10; i++) {
      const creditsContract = await gamePot.credits();
      await currency1.connect(users[i]).approve(creditsContract, parseEther("1000000"));
      await currency1.transfer(users[i].address, parseEther("10"));
      const beforeCreditBalance = await gamePot.getCreditBalanceOf(currency1, users[i].address);
      const beforeWinningBalance = await gamePot.getWinningBalanceOf(currency1, users[i].address);
      const beforeERC20Balance = await currency1.balanceOf(users[i].address);
      expect(beforeCreditBalance).to.equal(0);
      expect(beforeWinningBalance).to.equal(0);
      expect(beforeERC20Balance).to.equal(parseEther("10"));
      await gamePot.connect(users[i]).addCredits(currency1, parseEther("10"));
      const afterCreditBalance = await gamePot.getCreditBalanceOf(currency1,users[i].address);
      const afterWinningBalance = await gamePot.getWinningBalanceOf(currency1, users[i].address);
      const afterERC20Balance = await currency1.balanceOf(users[i].address);
      expect(afterCreditBalance).to.equal(parseEther("9"));
      expect(afterWinningBalance).to.equal(0);
      expect(afterERC20Balance).to.equal(0);
    }

    // Start game
    await gamePot.createGame(game_id, currency1, [3, 2, 1], users.slice(0, 10), parseEther("1"), parseEther("0"));

    // Check credits after starting
    for(let i = 0; i < 10; i++) {
      const afterJoinCreditBalance = await gamePot.getCreditBalanceOf(currency1,users[i].address);
      expect(afterJoinCreditBalance).to.equal(parseEther("8"));
    }

    // 10 people added 10 credits, profits should be 10
    // Joe Bloe should not be able to take profits 
    const beforeBal = await currency1.balanceOf(deployer.address);
    await expectThrow(gamePot.connect(users[0]).takeProfits(currency1), "Only owner can take profits");
    await gamePot.takeProfits(currency1);
    expect((await currency1.balanceOf(deployer.address)) - beforeBal).to.equal(parseEther("10")); 
  });
});