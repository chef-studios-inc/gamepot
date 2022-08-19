// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Import this file to use console.log
import "hardhat/console.sol";
import "./GameState/GameState.sol";
import "./PrizePool/PrizePool.sol";
import "./GameModeration/GameModeration.sol";

/// @title GamePot
/// @author Neil Dwyer (neil@chefstudios.com)
/// @notice A simple contract that represents a game's state machine 
///         where users buy-in to a reward pool and a percentage gets
///         paid out to the top users with some percentage going to
///         the contract's owner
contract GamePot {
  PrizePool public prizePool;
  GameState public gameState;
  GameModeration public gameModeration;
  address creator;

  constructor() {
    creator = msg.sender;
    prizePool = new PrizePool();
    gameState = new GameState();
    gameModeration = new GameModeration();
  }

  // Player Methods
  function joinGame(uint game_id) public {
    require(gameState.getGameState(game_id) == GameState.GameState.PREGAME, "game must be in PREGAME state to join");
    prizePool.joinPrizePool(game_id, msg.sender);
  }

  function cashOut(uint game_id) public {
    prizePool.cashOut(game_id, msg.sender);
  }

  function addCredits(uint game_id, uint amount) public {
    prizePool.addCredits(game_id, amount, msg.sender); 
  }

  function getMyCreditBalance(uint game_id) public view returns (uint) {
    return prizePool.getCreditBalance(game_id, msg.sender);
  }

  function getCreditBalanceOf(uint game_id, address addr) public view returns (uint) {
    return prizePool.getCreditBalance(game_id, addr);
  }

  // Moderation Management Methods

  function setOwner(uint game_id, address newOwner) public {
    gameModeration.setOwner(game_id, newOwner, msg.sender);
  }

  function addMod(uint game_id, address mod) public {
    gameModeration.setOwner(game_id, mod, msg.sender);
  }

  function removeMod(uint game_id, address mod) public {
    gameModeration.setOwner(game_id, mod, msg.sender);
  }

  function isModOrOwner(uint game_id, address addr) public returns (bool) {
    return gameModeration.isModOrOwner(game_id, addr);
  }

  // Moderation Methods 
  function createGame(uint game_id, ERC20 currency, uint price, uint percentageOfPlayersPaidOut, uint royaltyPercentOfTotalPrizePool) public {
    PrizePoolRoyaltySplit memory creatorSplit = PrizePoolRoyaltySplit(msg.sender, 50);
    PrizePoolRoyaltySplit memory contractSplit = PrizePoolRoyaltySplit(creator, 50);

    PrizePoolRoyaltySplit[] memory splits = new PrizePoolRoyaltySplit[](2);
    splits[0] = contractSplit;
    splits[1] = creatorSplit;

    PrizePoolSettings memory settings = PrizePoolSettings(splits, price, percentageOfPlayersPaidOut, royaltyPercentOfTotalPrizePool);

    gameState.createGame(game_id);
    prizePool.createPool(game_id, currency, settings);
    gameModeration.createGame(game_id, msg.sender);
  }

  function startGame(uint game_id, address[] calldata players) public {
    require(isModOrOwner(game_id, msg.sender), "must be mod or owner to call this function");
    gameState.startGame(game_id, players);
    prizePool.commitAddressesToPool(game_id, players);
  }

  function completeGame(uint game_id, address[] calldata leaderboard) public {
    require(isModOrOwner(game_id, msg.sender), "must be mod or owner to call this function");
    gameState.completeGame(game_id, leaderboard);
    prizePool.awardLeaderboard(game_id, leaderboard);
  }

  function resetGame(uint game_id) public {
    require(isModOrOwner(game_id, msg.sender), "must be mod or owner to call this function");
    gameState.resetGame(game_id);
  }

  function cancelGame(uint game_id) public {
    require(isModOrOwner(game_id, msg.sender), "must be mod or owner to call this function");
    gameState.cancelGame(game_id);
    prizePool.refundPool(game_id);
  }
}
