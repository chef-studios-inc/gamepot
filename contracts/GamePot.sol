// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Import this file to use console.log
import "hardhat/console.sol";
import "./GameState/GameState.sol";
import "./GameModeration/GameModeration.sol";
import "./Credits/Credits.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title GamePot
/// @author Neil Dwyer (neil@chefstudios.com)
/// @notice A simple contract that represents a game's state machine 
///         where users buy-in to a reward pool and a percentage gets
///         paid out to the top users with some percentage going to
///         the contract's owner
contract GamePot {
  GameState public gameState;
  GameModeration public gameModeration;
  Credits public credits;
  address creator;

  constructor() {
    creator = msg.sender;
    credits = new Credits();
    gameState = new GameState();
    gameModeration = new GameModeration();
  }

  // Player Methods
  // function joinGame(uint game_id) public {
  //   require(gameState.getGameState(game_id) == GameState.GameState.PREGAME, "game must be in PREGAME state to join");
  //   prizePool.joinPrizePool(game_id, msg.sender);
  // }

  // function cashOut(uint game_id) public {
  //   prizePool.cashOut(game_id, msg.sender);
  // }

  // function addCredits(uint game_id, uint amount) public {
  //   prizePool.addCredits(game_id, amount, msg.sender); 
  // }

  // function getCreditBalanceOf(uint game_id, address addr) public view returns (uint) {
  //   return prizePool.getCreditBalance(game_id, addr);
  // }

  // function isJoined(uint game_id, address addr) public view returns (bool) {
  //   return prizePool.isJoined(game_id, addr);
  // }

  // Moderation Management Methods

  function setOwner(uint game_id, address newOwner) public {
    gameModeration.setOwner(game_id, newOwner, msg.sender);
  }

  function addMod(uint game_id, address mod) public {
    gameModeration.addMod(game_id, mod, msg.sender);
  }

  function removeMod(uint game_id, address mod) public {
    gameModeration.setOwner(game_id, mod, msg.sender);
  }

  function isModOrOwner(uint game_id, address addr) public view returns (bool) {
    return gameModeration.isModOrOwner(game_id, addr);
  }

  function getOwner(uint game_id) public view returns(address) {
    return gameModeration.getOwner(game_id);
  }

  // Moderation Methods 
  function createGame(uint game_id, ERC20 currency, uint price, uint percentageOfPlayersPaidOut, uint royaltyPercentOfTotalPrizePool, address[] calldata royaltyRecipients, uint[] calldata royaltyPercentages) public {
    // require(royaltyRecipients.length == royaltyPercentages.length, "Royalty recipients and percentages must be same length");

    // uint length = royaltyRecipients.length;

    // PrizePoolRoyaltySplit[] memory splits = new PrizePoolRoyaltySplit[](length + 1); // + 1 because the contract always gets paid
    // PrizePoolRoyaltySplit memory contractSplit = PrizePoolRoyaltySplit(creator, 50);
    // splits[0] = contractSplit;
    
    // uint remaining = 50;
    // for(uint i = 0; i < length; i++) {
    //   address recipient = royaltyRecipients[i];
    //   uint percentage = royaltyPercentages[i] / 2;

    //   // if the last one, give them the remaining to ensure we still add to 100
    //   if(i == length - 1) {
    //     percentage = remaining;
    //   } else {
    //     remaining -= percentage;
    //   }

    //   PrizePoolRoyaltySplit memory split = PrizePoolRoyaltySplit(recipient, percentage);
    //   splits[i + 1] = split;
    // }

    // PrizePoolSettings memory settings = PrizePoolSettings(splits, price, percentageOfPlayersPaidOut, royaltyPercentOfTotalPrizePool);

    // gameState.createGame(game_id);
    // prizePool.createPool(game_id, currency, settings);
    // gameModeration.createGame(game_id, msg.sender);
  }

  function startGame(uint game_id, address[] calldata players) public {
    require(isModOrOwner(game_id, msg.sender), "must be mod or owner to call this function");
    gameState.startGame(game_id, players);
    // prizePool.commitAddressesToPool(game_id, players);
  }

  function completeGame(uint game_id, address[] calldata leaderboard) public {
    require(isModOrOwner(game_id, msg.sender), "must be mod or owner to call this function");
    gameState.completeGame(game_id, leaderboard);
    // prizePool.awardLeaderboard(game_id, leaderboard);
  }

  function resetGame(uint game_id) public {
    require(isModOrOwner(game_id, msg.sender), "must be mod or owner to call this function");
    gameState.resetGame(game_id);
  }

  function cancelGame(uint game_id) public {
    require(isModOrOwner(game_id, msg.sender), "must be mod or owner to call this function");
    gameState.cancelGame(game_id);
    // prizePool.refundPool(game_id);
  }

  // Game state 
  function isPregame(uint game_id) public view returns (bool) {
    return gameState.isPregame(game_id);
  }

  function isPlaying(uint game_id) public view returns (bool) {
    return gameState.isPlaying(game_id);
  }

  function isComplete(uint game_id) public view returns (bool) {
    return gameState.completeGames(game_id);
  }
}
