import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";
import { BigNumber } from "ethers";
import { GamePot, GamePot__factory } from "../typechain-types";
import exp from "constants";

describe("GamePot", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshopt in every test.
  async function deployGamePot() {
    // Contracts are deployed using the first signer/account by default
    const [
      gameController,
      ...users
    ] = await ethers.getSigners();

    const GamePot = await ethers.getContractFactory("GamePot");
    const gamePot = await GamePot.deploy();
    await gamePot.addGameController(gameController.address);

    return { gamePot, gameController, users };
  }

  describe("Settings", function () {
    it("Should be able to set price", async function () {
      const { gamePot } = await loadFixture(deployGamePot);
      expect(await gamePot.price()).equals(0);
      await gamePot.setPrice(ethers.utils.parseEther("1"));
      const newPrice = await gamePot.price();
      expect(newPrice, "price should have been set").equals(ethers.utils.parseEther("1"));
    });
  });

  describe("Game State Machine", function () {
    it("Non GAMECONTROLLER should not be able to start game", async function() {
      const { gamePot, users } = await loadFixture(deployGamePot);
      const userGamePot = await gamePot.connect(users[1])
      await expect(userGamePot.startGame([users[0].address, users[1].address])).to.be.rejected;
    });

    it("GAMECONTROLLER not enought balance can't play", async function() {
      const { gamePot, users } = await loadFixture(deployGamePot);
      gamePot.setPrice(ethers.utils.parseEther("1"));
      const price = await gamePot.price();
      const user1GP = await gamePot.connect(users[0])
      const user2GP = await gamePot.connect(users[1])
      const user3GP = await gamePot.connect(users[2])
      await user1GP.buyIn({value: price});
      await user2GP.buyIn({value: price});
      await user3GP.buyIn({ value: ethers.utils.parseEther("0.5") });
      await gamePot.startGame([users[0].address, users[1].address, users[2].address]);
      const playersInGameCount = await gamePot.playersInGameCount();
      expect(BigNumber.from(2).eq(playersInGameCount), "One user doesn't have enought balance").to.be.true;
    });

    for (let playerCount = 2; playerCount < 15; playerCount++) {
      it(`GAMECONTROLLER game e2e (PLAYERS: ${playerCount})`, async function () {
        const { gamePot, users } = await loadFixture(deployGamePot);
        gamePot.setPrice(ethers.utils.parseEther("1"));
        const price = await gamePot.price();
        const userGPs: GamePot[] = [];

        const startBalance = await gamePot.provider.getBalance(gamePot.address);
        const ownerWallet = await gamePot.signer.getAddress();
        const startOwnerWalletBalance = await gamePot.provider.getBalance(ownerWallet);

        for(let i = 0; i < playerCount; i++) {
          const gp = await gamePot.connect(users[i]);
          await gp.buyIn({value: price});
          userGPs.push(gp);
        }

        const afterPaymentBalance = await gamePot.provider.getBalance(gamePot.address);

        expect(
          afterPaymentBalance.sub(startBalance).eq(price.mul(playerCount)),
          "Contract should have been paid"
        ).to.be.true;

        const addresses = users.slice(0, playerCount).map(u => u.address);
        await gamePot.startGame(addresses);
        const playersInGameCount = await gamePot.playersInGameCount();

        expect(
          BigNumber.from(playerCount).eq(playersInGameCount),
          "Players all made it into the game"
        ).to.be.true;

        await gamePot.endGame(addresses)

        const winnerAmount = await gamePot.playerBalances(users[0].address);
        expect(winnerAmount.gt(price), "winner should always make money").to.be.true;
        for(let i = 0; i < (playerCount - 1); i++) {
          const p1 = await gamePot.playerBalances(users[i].address);
          const p2 = await gamePot.playerBalances(users[i + 1].address);
          expect(p1.gte(p2), "better performers should have a bigger reward").to.be.true;
        }

        // winner cash out
        const beforeBalance = await users[0].getBalance();
        await userGPs[0].cashOut();
        const afterBalance = await users[0].getBalance();
        expect(afterBalance.sub(beforeBalance).gt(price), "winner should be profitable after cashing out");


        for(let i = 0; i < (playerCount); i++) {
          const balance = await gamePot.playerBalances(users[i].address);
          if(balance.gt(BigNumber.from(0))) {
            await userGPs[i].cashOut();
          }
        }

        const afterCashoutBalance = await gamePot.provider.getBalance(gamePot.address);
        expect(afterCashoutBalance.gt(startBalance), "contract must be profitable").to.be.true;

        await gamePot.takeProfits();
        const afterTakeProfitsBalance = await gamePot.provider.getBalance(gamePot.address);
        expect(afterTakeProfitsBalance.eq(0), "No balance left after taking profits").to.be.true;
        const ownerBalance = await gamePot.provider.getBalance(ownerWallet);
        expect(ownerBalance.gt(startOwnerWalletBalance), "after taking profits, owner wallet should have more ETH").to.be.true;
      });
    }
  })
});
