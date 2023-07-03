// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

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
  event GameCreated(uint256 game_id);

  constructor() {
    creator = msg.sender;
    credits = new Credits();
  }

  // Player Methods
  function takeWinnings(ERC20 currency) public {
    credits.takeWinnings(msg.sender, currency);
  }

  function addCredits(ERC20 currency, uint amount) public {
    credits.addCredits(msg.sender, currency, amount);
  }

  function getCreditBalanceOf(ERC20 currency, address addr) public view returns (uint) {
    return credits.getCreditBalance(addr, currency);
  }

  function getWinningBalanceOf(ERC20 currency, address addr) public view returns (uint) {
    return credits.getWinningBalance(addr, currency);
  }

  function isJoined(uint game_id, address addr) public view returns (bool) {
    return credits.isJoined(addr, game_id);
  }

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
  function createGame(uint256 game_id, ERC20 currency, uint[] calldata payoutWeights, address[] calldata playersWallets, uint cost, uint boost) public {
    require(msg.sender == creator || admins[msg.sender], "must be creator or admin to call this function");
    credits.startPrizePool(game_id, currency, payoutWeights, playersWallets, cost, boost);
    emit GameCreated(game_id);
  }

  function completeGame(uint game_id, address[] calldata leaderboard) public {
    require(msg.sender == creator || admins[msg.sender], "must be creator or admin to call this function");
    credits.payoutPrizePool(game_id, leaderboard);
  }

  function cancelGame(uint game_id) public {
    require(msg.sender == creator || admins[msg.sender], "must be creator or admin to call this function");
    credits.refundPool(game_id);
  }

  function setRoyaltyPercentage(uint royaltyPercentage) public {
    require(msg.sender == creator || admins[msg.sender], "must be creator or admin to call this function");
    credits.setRoyaltyPercentage(royaltyPercentage);
  }

  function takeProfits(ERC20 currency) public {
    require(msg.sender == creator || admins[msg.sender], "must be creator or admin to call this function");
    credits.takeProfits(msg.sender, currency);
  }
}
