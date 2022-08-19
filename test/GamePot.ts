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
    const { gamePot, currency1, currency2, users } = await loadFixture(deployPrizePool);
    const players = users.slice(3, 8);

    const gp0 = await gamePot.connect(users[0]);

    await gp0.createGame(1, currency1.address, utils.parseEther("1"), BigNumber.from(40), BigNumber.from(10));

    for(let i = 0; i < players.length; i++) {
      await currency1.transfer(players[i].address, utils.parseEther("10"));
      const gp = gamePot.connect(players[i]);
      const cur = currency1.connect(players[i]);
      const prizePool = await gamePot.prizePool();
      await cur.approve(prizePool, utils.parseEther("1000000000"));
      await gp.addCredits(1, utils.parseEther("5"));
      await gp.joinGame(1);
    }

    // random user can't start game
    const playerGp = await gamePot.connect(players[0]);
    await expectThrow(playerGp.startGame(1, players.map(p => p.address)), "non owner can't start game");

    // owner can start game
    await expectNoThrow(gp0.startGame(1, players.map(p => p.address)), "owner can start game");

    await gp0.completeGame(1, players.map(p => p.address));

    // royalties got paid out
    const royalty1gp = await gamePot;
    const royalty2gp = await gp0;
    const before1 = await royalty1gp.getMyCreditBalance(1);
    const before2 = await royalty2gp.getMyCreditBalance(1);
    await royalty1gp.cashOut(1);
    await royalty2gp.cashOut(1);
    const after1 = await royalty1gp.getMyCreditBalance(1);
    const after2 = await royalty2gp.getMyCreditBalance(1);

    expect(after1.gt(before1), "royalties got paid out").to.be.true;
    expect(after2.gt(before1), "royalties got paid out").to.be.true;




    // winner won something
    const winnergp = await gamePot.connect(players[0]);
    const winnerCredits = await winnergp.getMyCreditBalance(1);
    expect(winnerCredits.gt(utils.parseEther("5")), "winner should have made money").to.be.true;
  });
});