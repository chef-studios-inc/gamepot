import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";
import { BigNumber } from "ethers";
import { GameState, GameState__factory } from "../../typechain-types";
import exp from "constants";
import {expectThrow, expectNoThrow} from "../utils/utils";

describe("GameState", function () {
  async function deployGameState() {
    // Contracts are deployed using the first signer/account by default
    const users = await ethers.getSigners();
    const GameState = await ethers.getContractFactory("GameState");
    const gameState = await GameState.deploy();

    return { gameState, users };
  }

  describe("Create a game", async function () {
    it("Should be able to create games", async function () {
      const { gameState } = await loadFixture(deployGameState);
      await expectNoThrow(gameState.createGame(123), "should be able to create a game");
      await expectThrow(gameState.createGame(123), "should not be able to create a duplicate game");
      await expectNoThrow(gameState.createGame(1234), "should be able to create a unique game");
    });
  });

  describe("Play a game", async function () {
    it("Should be able to go through the game state machine", async function () {
      const { gameState, users } = await loadFixture(deployGameState);
      await gameState.createGame(123);
      let addresses = [users[0], users[1], users[2]].map(u => u.address);

      // should be in pregame state
      expect(await gameState.getGameState(123)).to.eql(0);
      await expectThrow(gameState.getGameState(1234), "non existent game should throw");

      // start the game
      await expectNoThrow(gameState.startGame(123, addresses), "should be able to start the game");

      // check if players in game (and others not)
      expect(await gameState.checkIfPlayerInGame(123, users[1].address)).to.be.true;
      expect(await gameState.checkIfPlayerInGame(123, users[4].address)).to.be.false;
      await expectThrow(gameState.checkIfPlayerInGame(1234, users[1].address), "non existent game should throw");

      // should be in playing state
      expect(await gameState.getGameState(123)).to.eql(1);

      // stop the game
      await expectThrow(gameState.completeGame(123, [users[1].address, users[2].address]), "incomplete leaderboard is invalid");
      await expectThrow(gameState.completeGame(123, [users[4].address, users[1].address, users[2].address]), "leaderboard with unknown user is invalid");
      await expectNoThrow(gameState.completeGame(123, [users[2].address, users[1].address, users[0].address]), "valid leaderboard is valid");
      await expectThrow(gameState.completeGame(1234, []), "non existent game should throw");

      // should be in complete state
      expect(await gameState.getGameState(123)).to.eql(2);

      // reset the game
      await expectNoThrow(gameState.resetGame(123), "game should reset");
      await expectThrow(gameState.resetGame(1234), "non existent game should throw");

      // should be in pregame state
      expect(await gameState.getGameState(123)).to.eql(0);

      /*************** do it again but with some different users *****************/

      // different users, one overlap from previous game
      addresses = [users[2], users[3], users[4]].map(u => u.address);

      // should be in pregame state
      expect(await gameState.getGameState(123)).to.eql(0);
      await expectThrow(gameState.getGameState(1234), "non existent game should throw");

      // start the game
      await expectNoThrow(gameState.startGame(123, addresses), "should be able to start the game");

      // check if players in game (and others not)
      expect(await gameState.checkIfPlayerInGame(123, users[4].address)).to.be.true;
      expect(await gameState.checkIfPlayerInGame(123, users[1].address), "previous game player should no longer be in the game").to.be.false;
      await expectThrow(gameState.checkIfPlayerInGame(1234, users[1].address), "non existent game should throw");

      // should be in playing state
      expect(await gameState.getGameState(123)).to.eql(1);

      // stop the game
      await expectNoThrow(gameState.completeGame(123, addresses), "game should complete");
      await expectThrow(gameState.completeGame(1234, []), "non existent game should throw");

      // should be in complete state
      expect(await gameState.getGameState(123)).to.eql(2);

      // reset the game
      await expectNoThrow(gameState.resetGame(123), "game should reset");
      await expectThrow(gameState.resetGame(1234), "non existent game should throw");

      // should be in pregame state
      expect(await gameState.getGameState(123)).to.eql(0);
    });
  });

  describe("Cancel a game", async function () {
    it("Should be able to cancel games", async function () {
      const { gameState, users } = await loadFixture(deployGameState);
      await gameState.createGame(123);
      await gameState.startGame(123, [users[0].address, users[1].address]);
      expect(await gameState.checkIfPlayerInGame(123, users[0].address)).to.be.true;
      await gameState.cancelGame(123);
      expect(await gameState.checkIfPlayerInGame(123, users[0].address)).to.be.false;
      expect(await gameState.getGameState(123)).to.eql(0);
    });

    it("Should not be able to cancel a non-started game", async function () {
      const { gameState, users } = await loadFixture(deployGameState);
      await gameState.createGame(123);
      await expectThrow(gameState.cancelGame(123), "cancelling a non-started game should throw");
    });
  });

});