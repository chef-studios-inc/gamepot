import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";
import { BigNumber } from "ethers";
import { GameState, GameState__factory } from "../../typechain-types";
import exp from "constants";
import {expectThrow, expectNoThrow} from "../utils/utils";

describe("GameModeration", function () {
  async function deployGameState() {
    // Contracts are deployed using the first signer/account by default
    const users = await ethers.getSigners();
    const GameModeration = await ethers.getContractFactory("GameModeration");
    const gameModeration = await GameModeration.deploy();

    return { gameModeration, users };
  }

  describe("Create a game", async function () {
    it("Creators should be owners", async function () {
      const { gameModeration, users } = await loadFixture(deployGameState);
      await expectNoThrow(gameModeration.createGame(123, users[0].address), "should be able to create a game");
      await expectNoThrow(gameModeration.createGame(456, users[1].address), "should be able to create a game");
      expect(await gameModeration.isOwner(123, users[0].address)).to.be.true;
      expect(await gameModeration.isOwner(456, users[1].address)).to.be.true;

      expect(await gameModeration.isOwner(123, users[1].address)).to.be.false;
      expect(await gameModeration.isOwner(456, users[0].address)).to.be.false;
    });

    it("Owner should be a modOrOwner", async function () {
      const { gameModeration, users } = await loadFixture(deployGameState);
      await expectNoThrow(gameModeration.createGame(123, users[0].address), "should be able to create a game");
      expect(await gameModeration.isModOrOwner(123, users[0].address)).to.be.true;
    });

    it("Owner should be a modOrOwner", async function () {
      const { gameModeration, users } = await loadFixture(deployGameState);
      await expectNoThrow(gameModeration.createGame(123, users[0].address), "should be able to create a game");
      expect(await gameModeration.isModOrOwner(123, users[0].address)).to.be.true;
    });

    it("Random user should not be a mod or owner", async function () {
      const { gameModeration, users } = await loadFixture(deployGameState);
      await expectNoThrow(gameModeration.createGame(123, users[0].address), "should be able to create a game");
      expect(await gameModeration.isOwner(123, users[1].address)).to.be.false;
      expect(await gameModeration.isModOrOwner(123, users[1].address)).to.be.false;
    });

    it("Only owner can add or remove mod", async function () {
      const { gameModeration, users } = await loadFixture(deployGameState);
      await expectNoThrow(gameModeration.createGame(123, users[0].address), "should be able to create a game");
      await expectThrow(gameModeration.addMod(123, users[2].address, users[1].address), "non owner can't set a mod");
      await expectThrow(gameModeration.addMod(123, users[3].address, users[1].address), "non owner can't set a mod");
      expect(await gameModeration.isModOrOwner(123, users[2].address), "old owner should not be mod or owner").to.be.false;
      expect(await gameModeration.isModOrOwner(123, users[3].address), "old owner should not be mod or owner").to.be.false;

      await expectNoThrow(gameModeration.addMod(123, users[2].address, users[0].address), "owner can set a mod");
      await expectNoThrow(gameModeration.addMod(123, users[3].address, users[0].address), "owner can set a mod");
      expect(await gameModeration.isModOrOwner(123, users[2].address), "old owner should not be mod or owner").to.be.true;
      expect(await gameModeration.isModOrOwner(123, users[3].address), "old owner should not be mod or owner").to.be.true;

      await expectThrow(gameModeration.removeMod(123, users[2].address, users[1].address), "non owner can't remove a mod");
      await expectThrow(gameModeration.removeMod(123, users[3].address, users[1].address), "non owner can't remove a mod");
      expect(await gameModeration.isModOrOwner(123, users[2].address), "old owner should not be mod or owner").to.be.true;
      expect(await gameModeration.isModOrOwner(123, users[3].address), "old owner should not be mod or owner").to.be.true;

      await expectNoThrow(gameModeration.removeMod(123, users[2].address, users[0].address), "non owner can't remove a mod");
      await expectNoThrow(gameModeration.removeMod(123, users[3].address, users[0].address), "non owner can't remove a mod");
      expect(await gameModeration.isModOrOwner(123, users[2].address), "old owner should not be mod or owner").to.be.false;
      expect(await gameModeration.isModOrOwner(123, users[3].address), "old owner should not be mod or owner").to.be.false;
    });

    it("Only owner can set owner", async function () {
      const { gameModeration, users } = await loadFixture(deployGameState);
      await expectNoThrow(gameModeration.createGame(123, users[0].address), "should be able to create a game");
      await expectThrow(gameModeration.setOwner(123, users[1].address, users[1].address), "non owner can't set an owner");
      await expectNoThrow(gameModeration.setOwner(123, users[1].address, users[0].address), "owner can set new owner");

      expect(await gameModeration.isOwner(123, users[0].address), "old owner should not be owner").to.be.false;
      expect(await gameModeration.isModOrOwner(123, users[0].address), "old owner should not be mod or owner").to.be.false;

      expect(await gameModeration.isOwner(123, users[1].address), "new owner should be mod or owner").to.be.true;
      expect(await gameModeration.isModOrOwner(123, users[1].address), "new owner should be mod or owner").to.be.true;
    });

  });

});