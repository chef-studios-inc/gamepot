// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./PrizePoolRoyaltySplit.sol";
import "./PrizePoolSettings.sol";

contract PrizePool {
  address private contractCreator;

  mapping (uint => bool) public existingPools;
  mapping (uint => ERC20) public poolCurrency;

  mapping (uint256 => uint) public creditBalances;
  mapping (uint => uint) public prizePoolTotals;
  mapping (uint256 => uint) public playerPrizePoolBalances; 

  function createPool(uint pool_id, ERC20 currency) public {
    require(msg.sender == contractCreator, "this contract can only be called by its creator");
    require(existingPools[pool_id] == false, "pool_id already exists, please choose another");
    existingPools[pool_id] = true;
    poolCurrency[pool_id] = currency;
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

  function joinPrizePool(uint pool_id, uint amount, address caller) public {
    require(msg.sender == contractCreator, "this contract can only be called by its creator");
    require(existingPools[pool_id] == true, "pool_id doesn't exist");

    uint256 key = getBalanceKey(pool_id, caller);

    require(creditBalances[key] >= amount, "this player doesn't have enough credits to join the prize pool at this amount");

    creditBalances[key] -= amount;
    prizePoolTotals[pool_id] += amount;
    playerPrizePoolBalances[key] += amount;
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
  function awardLeaderboard(uint pool_id, address[] calldata leaderboard, PrizePoolSettings calldata settings) public {
    require(msg.sender == contractCreator, "this contract can only be called by its creator");
    require(settings.totalRoyaltyPercent < 100, "royaltyPercent cannot be more than 100");
    requireRoyaltySplitAddTo100(settings.royaltySplits);

    uint totalPrizePool = prizePoolTotals[pool_id];
    uint lastAwardedIndexTimes100 = leaderboard.length * settings.topPercentOfPlayersPaidOut;
    uint payoutRemaining = totalPrizePool;
    uint paidOut;

    // pay out royalties
    for(uint i = 0; i < settings.royaltySplits.length; i++) {
      uint256 key = getBalanceKey(pool_id, settings.royaltySplits[i].recipient);
      uint payout = (totalPrizePool * settings.royaltySplits[i].percentage) / 100;
      creditBalances[key] += payout;
      payoutRemaining -= payout;
      paidOut += payout;
    }

    // pay out players
    for(uint i = 0; i < leaderboard.length; i++) {
      uint256 key = getBalanceKey(pool_id, leaderboard[i]);
      require(playerPrizePoolBalances[key] == settings.joinPoolPrice, "player balance must be the same as the buy in price");
      uint payout;
      uint multiplerReductionTimesPriceDividedBy100 = settings.firstPlaceMultiplier * i * settings.joinPoolPrice / lastAwardedIndexTimes100;

      payout = (settings.firstPlaceMultiplier * settings.joinPoolPrice - multiplerReductionTimesPriceDividedBy100 * 100);
      if(payout + paidOut > payoutRemaining) {
        payout = payoutRemaining;
      }
      paidOut += payout;
      playerPrizePoolBalances[key] = 0;
      creditBalances[key] += payout;
    }

    require(paidOut == totalPrizePool, "All of the prize pool must be paid out");
    prizePoolTotals[pool_id] = 0;
  }

  function refundPool(uint pool_id, address[] calldata players) public {
    require(msg.sender == contractCreator, "this contract can only be called by its creator");

    uint totalRefunded;
    for(uint i = 0; i < players.length; i++) {
      uint256 key = getBalanceKey(pool_id, players[i]);
      uint balance = playerPrizePoolBalances[key];
      playerPrizePoolBalances[key] = 0;
      creditBalances[key] += balance;
      totalRefunded += balance;
    }

    prizePoolTotals[pool_id] -= totalRefunded;
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

  function getBalanceKey(uint pool_id, address addr) private pure returns (uint256) {
    return uint256(keccak256(abi.encode(pool_id, addr)));
  }

  function requireRoyaltySplitAddTo100(PrizePoolRoyaltySplit[] calldata splits) private pure {
    uint totalRoyaltySplit;
    for(uint i = 0; i < splits.length; i++) {
      totalRoyaltySplit += splits[i].percentage;
    }

    require(totalRoyaltySplit == 100, "royalty split must add up to 100");
  }
}