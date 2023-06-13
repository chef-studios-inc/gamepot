// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Import this file to use console.log
import "hardhat/console.sol";
import "./Credits/Credits.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title GamePot
/// @author Neil Dwyer (neil@chefstudios.com)
/// @notice A simple contract that represents a game's state machine 
///         where users buy-in to a reward pool and a percentage gets
///         paid out to the top users with some percentage going to
///         the contract's owner
contract GamePot {
  Credits public credits;
  address creator;
  mapping(address => bool) admins;
  uint latestGameId = 0;

  constructor() {
    creator = msg.sender;
    credits = new Credits();
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
  function setAdmin(address admin) public {
    require(msg.sender == creator, "must be creator to call this function");
    admins[admin] = true;
  }

  function unsetAdmin(address admin) public {
    require(msg.sender == creator, "must be creator to call this function");
    admins[admin] = false;
  }

  // Moderation Methods 
  function createGame(ERC20 currency, uint[] calldata poolWeights, uint cost, uint boost) public returns(uint) {
    require(msg.sender == creator || admins[msg.sender], "must be creator or admin to call this function");
    latestGameId++;
    credits.startPrizePool(latestGameId, currency, poolWeights, cost, boost);
    return latestGameId;
  }

  function completeGame(uint game_id, address[] calldata leaderboard) public {
    require(msg.sender == creator || admins[msg.sender], "must be creator or admin to call this function");
    credits.payoutPrizePool(game_id, leaderboard);
  }

  function cancelGame(uint game_id) public {
    require(msg.sender == creator || admins[msg.sender], "must be creator or admin to call this function");
    credits.refundPool(game_id);
  }
}
