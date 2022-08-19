// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Import this file to use console.log
import "hardhat/console.sol";
import "./GameState/GameState.sol";
import "./PrizePool/PrizePool.sol";

/// @title GamePot
/// @author Neil Dwyer (neil@chefstudios.com)
/// @notice A simple contract that represents a game's state machine 
///         where users buy-in to a reward pool and a percentage gets
///         paid out to the top users with some percentage going to
///         the contract's owner
contract GamePot {
  PrizePool public prizePool;
  GameState public gameState;
  address creator;
  mapping (uint => address) gameOwners;

  constructor() {
    creator = msg.sender;
    prizePool = new PrizePool();
    gameState = new GameState();
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
    gameOwners[game_id] = msg.sender;
  }

  function startGame(uint game_id, address[] calldata players) public {
    require(gameOwners[game_id] == msg.sender, "must be game owner to call this action");
    gameState.startGame(game_id, players);
    prizePool.commitAddressesToPool(game_id, players);
  }

  function completeGame(uint game_id, address[] calldata leaderboard) public {
    require(gameOwners[game_id] == msg.sender, "must be game owner to call this action");
    gameState.completeGame(game_id, leaderboard);
    prizePool.awardLeaderboard(game_id, leaderboard);
  }

  function resetGame(uint game_id) public {
    require(gameOwners[game_id] == msg.sender, "must be game owner to call this action");
    gameState.resetGame(game_id);
  }

  function cancelGame(uint game_id) public {
    require(gameOwners[game_id] == msg.sender, "must be game owner to call this action");
    gameState.cancelGame(game_id);
    prizePool.refundPool(game_id);
  }
}
