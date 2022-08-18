// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./PrizePoolRoyaltySplit.sol";
import "./PrizePoolSettings.sol";
import "hardhat/console.sol";

contract PrizePool {
  address private contractCreator;

  mapping (uint => bool) public existingPools;
  mapping (uint => ERC20) public poolCurrency;
  mapping (uint => PrizePoolSettings) public poolSettings;

  mapping (uint256 => uint) public creditBalances;
  mapping (uint => uint) public prizePoolTotals;
  mapping (uint => address[]) public playersWithPoolBalances;
  mapping (uint256 => bool) public playerPoolBalanceLookup; 

  constructor() {
    contractCreator = msg.sender;
  }

  function createPool(uint pool_id, ERC20 currency, PrizePoolSettings calldata settings) public {
    require(msg.sender == contractCreator, "this contract can only be called by its creator");
    require(existingPools[pool_id] == false, "pool_id already exists, please choose another");
    existingPools[pool_id] = true;
    poolCurrency[pool_id] = currency;
    poolSettings[pool_id] = settings;
  } 

  function addCredits(uint pool_id, uint amount, address caller) public {
    require(msg.sender == contractCreator, "this contract can only be called by its creator");
    require(existingPools[pool_id] == true, "pool_id doesn't exist");
    ERC20 currency = poolCurrency[pool_id];
    uint256 key = getBalanceKey(pool_id, caller);

    creditBalances[key] += amount;

    if(!currency.transferFrom(caller, address(this), amount)) {
      creditBalances[key] -= amount;
    }
  }

  function joinPrizePool(uint pool_id, address caller) public {
    require(msg.sender == contractCreator, "this contract can only be called by its creator");
    require(existingPools[pool_id] == true, "pool_id doesn't exist");

    uint256 key = getBalanceKey(pool_id, caller);

    uint amount = poolSettings[pool_id].joinPoolPrice;

    require(creditBalances[key] >= amount, "this player doesn't have enough credits to join the prize pool at this amount");
    require(playerPoolBalanceLookup[key] == false, "player already in prize pool");

    creditBalances[key] -= amount;
    prizePoolTotals[pool_id] += amount;
    playerPoolBalanceLookup[key] = true;
    playersWithPoolBalances[pool_id].push(caller);
  }

  /// @notice Equations
  /// ----------------------------------------
  /// Goal: Create a function f(x) = y where x is leaderboardIndex and y is price multiplier for award
  /// lastAwardedIndex = leaderboardLength * percentageOfPlayersAwarded / 100;
  /// f(x) = firstPlaceAwardMultiplier - b (x)
  /// f(lastAwardedIndex) = 0 = firstPlaceAwardMultipler - b (lastAwardedIndex)
  /// b = firstPlaceAwardMultipler / lastAwardedIndex
  /// therefore f(x) = firstPlaceAwardMultipler - (firstPlaceAwardMultiplier / lastAwardedIndex) * x
  /// @dev this function must be called in order from first place to last place
  function awardLeaderboard(uint pool_id, address[] calldata leaderboard) public {
    require(msg.sender == contractCreator, "this contract can only be called by its creator");
    PrizePoolSettings memory settings = poolSettings[pool_id];
    require(settings.totalRoyaltyPercent < 100, "royaltyPercent cannot be more than 100");
    requireRoyaltySplitAddTo100(settings.royaltySplits);

    uint totalPrizePool = prizePoolTotals[pool_id];
    uint royaltyPaidOut;

    // pay out royalties
    for(uint i = 0; i < settings.royaltySplits.length; i++) {
      uint256 key = getBalanceKey(pool_id, settings.royaltySplits[i].recipient);
      uint payout = (totalPrizePool * settings.totalRoyaltyPercent * settings.royaltySplits[i].percentage) / (100 * 100);
      creditBalances[key] += payout;
      royaltyPaidOut += payout;
    }

    uint firstPlaceDesiredPayout = settings.firstPlaceMultiplier * settings.joinPoolPrice;
    uint payoutRemaining = totalPrizePool - royaltyPaidOut;
    uint lastAwardedIndexTimes100 = leaderboard.length * settings.topPercentOfPlayersPaidOut;

    // pay out players
    for(uint i = 0; i < leaderboard.length; i++) {
      uint256 key = getBalanceKey(pool_id, leaderboard[i]);
      require(playerPoolBalanceLookup[key] == true, "player balance must be the same as the buy in price");
      uint payout;
      uint multiplierReductionTimesPriceDividedBy100 = firstPlaceDesiredPayout * i / lastAwardedIndexTimes100;

      if(payoutRemaining + multiplierReductionTimesPriceDividedBy100 * 100 <= firstPlaceDesiredPayout) {
        payout = payoutRemaining;
      } else {
        payout = (firstPlaceDesiredPayout - multiplierReductionTimesPriceDividedBy100 * 100);
      }

      console.log("NEIL ", payout);
      console.log("NEIL ", i);

      payoutRemaining -= payout;
      playerPoolBalanceLookup[key] = false;
      creditBalances[key] += payout;
    }

    require(payoutRemaining == 0, "All of the prize pool must be paid out");
    prizePoolTotals[pool_id] = 0;
    delete playersWithPoolBalances[pool_id];
  }

  function refundPool(uint pool_id) public {
    require(msg.sender == contractCreator, "this contract can only be called by its creator");

    address[] memory players = playersWithPoolBalances[pool_id];
    uint refundAmount = poolSettings[pool_id].joinPoolPrice;

    uint totalRefunded;
    for(uint i = 0; i < players.length; i++) {
      uint256 key = getBalanceKey(pool_id, players[i]);
      playerPoolBalanceLookup[key] = false;
      creditBalances[key] += refundAmount;
      totalRefunded += refundAmount;
    }

    prizePoolTotals[pool_id] -= totalRefunded;
    delete playersWithPoolBalances[pool_id];
  }

  function cashOut(uint pool_id, address player) public {
    require(msg.sender == contractCreator, "this contract can only be called by its creator");
    ERC20 currency = poolCurrency[pool_id];
    uint256 key = getBalanceKey(pool_id, player);
    uint credits = creditBalances[key];
    creditBalances[key] = 0;
    if(!currency.transferFrom(address(this), player, credits)) {
      creditBalances[key] = credits;
    }
  }

  function getCreditBalance(uint pool_id, address addr) public view returns(uint) {
    uint256 key = getBalanceKey(pool_id, addr);
    return creditBalances[key];
  }

  function getBalanceKey(uint pool_id, address addr) private pure returns (uint256) {
    return uint256(keccak256(abi.encode(pool_id, addr)));
  }

  function requireRoyaltySplitAddTo100(PrizePoolRoyaltySplit[] memory splits) private pure {
    uint totalRoyaltySplit;
    for(uint i = 0; i < splits.length; i++) {
      totalRoyaltySplit += splits[i].percentage;
    }

    require(totalRoyaltySplit == 100, "royalty split must add up to 100");
  }
}