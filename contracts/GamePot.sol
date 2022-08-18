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
  PrizePool private prizePool;
  GameState private gameState;
  address creator;

  constructor() {
    creator = msg.sender;
    prizePool = new PrizePool();
    gameState = new GameState();
  }

  function createGame(uint game_id, ERC20 currency, uint price, uint percentageOfPlayersPaidOut, uint royaltyPercentOfTotalPrizePool) public {
    PrizePoolRoyaltySplit memory creatorSplit = PrizePoolRoyaltySplit(msg.sender, 50);
    PrizePoolRoyaltySplit memory contractSplit = PrizePoolRoyaltySplit(creator, 50);

    PrizePoolRoyaltySplit[] memory splits = new PrizePoolRoyaltySplit[](2);
    splits[0] = contractSplit;
    splits[1] = creatorSplit;

    PrizePoolSettings memory settings = PrizePoolSettings(splits, price, percentageOfPlayersPaidOut, royaltyPercentOfTotalPrizePool);

    gameState.createGame(game_id);
    prizePool.createPool(game_id, currency, settings);
  }

  function joinGame(uint game_id) public {
    require(gameState.getGameState(game_id) == GameState.GameState.PREGAME, "game must be in PREGAME state to join");
    prizePool.joinPrizePool(game_id, msg.sender);
  }

  function startGame(uint game_id, address[] calldata players) public {
    gameState.startGame(game_id, players);
  }

  function getMyCreditBalance(uint game_id) public view returns (uint) {
    return prizePool.getCreditBalance(game_id, msg.sender);
  }

  function getCreditBalanceOf(uint game_id, address addr) public view returns (uint) {
    return prizePool.getCreditBalance(game_id, addr);
  }
}
