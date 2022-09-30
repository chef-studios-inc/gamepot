// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./PrizePoolRoyaltySplit.sol";
import "./PrizePoolSettings.sol";
import "hardhat/console.sol";

contract PrizePool {
  enum PrizePoolState { ACCEPTING_NEW_JOINS, CLOSED }
  address private contractCreator;

  mapping (uint => PrizePoolState) poolStates;
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
    poolStates[pool_id] = PrizePoolState.ACCEPTING_NEW_JOINS;
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
    require(poolStates[pool_id] == PrizePoolState.ACCEPTING_NEW_JOINS, "can't join the pool in this state");

    uint256 key = getBalanceKey(pool_id, caller);
    uint amount = poolSettings[pool_id].joinPoolPrice;

    require(creditBalances[key] >= amount, "this player doesn't have enough credits to join the prize pool at this amount");
    require(playerPoolBalanceLookup[key] == false, "player already in prize pool");

    creditBalances[key] -= amount;
    prizePoolTotals[pool_id] += amount;
    playerPoolBalanceLookup[key] = true;
    playersWithPoolBalances[pool_id].push(caller);
  }

  function commitAddressesToPool(uint pool_id, address[] calldata addresses) public {
    require(msg.sender == contractCreator, "this contract can only be called by its creator");
    require(poolStates[pool_id] == PrizePoolState.ACCEPTING_NEW_JOINS, "can't commit the pool in this state");
    uint price = poolSettings[pool_id].joinPoolPrice;

    address[] memory addressesInPool = playersWithPoolBalances[pool_id];

    uint totalRefunded;
    // remove addresses in pool who have not been committed
    for(uint j = 0; j < addressesInPool.length; j++) {
      uint256 key = getBalanceKey(pool_id, addressesInPool[j]);
      require(playerPoolBalanceLookup[key], "committed address not in pool");
      bool shouldCommitAddress = false;
      for(uint i = 0; i < addresses.length; i++) {
        if(addresses[i] == addressesInPool[j]) {
          shouldCommitAddress = true;
          break;
        }
      }
      if(shouldCommitAddress) {
        continue;
      }

      // refund addresses that aren't committed
      playerPoolBalanceLookup[key] = false;
      creditBalances[key] += price;
      totalRefunded += price;
    }

    prizePoolTotals[pool_id] -= totalRefunded;
    poolStates[pool_id] = PrizePoolState.CLOSED;
  }

  function awardLeaderboard(uint pool_id, address[] calldata leaderboard) public {
    require(msg.sender == contractCreator, "this contract can only be called by its creator");
    require(poolStates[pool_id] == PrizePoolState.CLOSED, "can't award leaderboard in this state");
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

    uint payoutRemaining = totalPrizePool - royaltyPaidOut;
    uint lastAwardedIndexTimes100 = leaderboard.length * settings.topPercentOfPlayersPaidOut + 1;
    
    // area of the triangle = the payout still remaining. Looking to find the slope of the triangle
    // slope = h/w
    // w = lastAwardedIndex
    // w * h = 2 * payoutRemaining
    // h = 2 * payoutRemaining * 100 / lastAwardedIndexTimes100
    uint yIntercept = 2 * payoutRemaining * 100 / lastAwardedIndexTimes100;
    uint slope = yIntercept * 100 / (lastAwardedIndexTimes100);

    // pay out players
    for(uint i = 0; i < leaderboard.length; i++) {
      uint256 key = getBalanceKey(pool_id, leaderboard[i]);
      require(playerPoolBalanceLookup[key] == true, "player balance must be the same as the buy in price");
      playerPoolBalanceLookup[key] = false;
      if(payoutRemaining == 0)  {
        break;
      }
      uint payout;
      uint decreaseBy = i * slope; //-mx
      if(yIntercept >= decreaseBy) {
        payout = yIntercept - decreaseBy;
        if(payout > payoutRemaining) {
          payout = payoutRemaining;
        }
      } else {
        payout = payoutRemaining;
      }

      payoutRemaining -= payout;
      creditBalances[key] += payout;
    }

    require(payoutRemaining == 0, "All of the prize pool must be paid out");
    prizePoolTotals[pool_id] = 0;
    delete playersWithPoolBalances[pool_id];
    poolStates[pool_id] = PrizePoolState.ACCEPTING_NEW_JOINS;
  }

  function refundPool(uint pool_id) public {
    require(msg.sender == contractCreator, "this contract can only be called by its creator");

    address[] memory players = playersWithPoolBalances[pool_id];
    uint refundAmount = poolSettings[pool_id].joinPoolPrice;

    uint totalRefunded;
    for(uint i = 0; i < players.length; i++) {
      uint256 key = getBalanceKey(pool_id, players[i]);
      if(!playerPoolBalanceLookup[key]) {
        continue;
      }
      playerPoolBalanceLookup[key] = false;
      creditBalances[key] += refundAmount;
      totalRefunded += refundAmount;
    }

    prizePoolTotals[pool_id] -= totalRefunded;
    delete playersWithPoolBalances[pool_id];
    poolStates[pool_id] = PrizePoolState.ACCEPTING_NEW_JOINS;
  }

  function cashOut(uint pool_id, address player) public {
    require(msg.sender == contractCreator, "this contract can only be called by its creator");
    ERC20 currency = poolCurrency[pool_id];
    uint256 key = getBalanceKey(pool_id, player);
    uint credits = creditBalances[key];
    creditBalances[key] = 0;
    if(!currency.transfer(player, credits)) {
      creditBalances[key] = credits;
    }
  }

  function getCreditBalance(uint pool_id, address addr) public view returns(uint) {
    uint256 key = getBalanceKey(pool_id, addr);
    return creditBalances[key];
  }

  function getBuyInPrice(uint pool_id) public view returns(uint) {
    return poolSettings[pool_id].joinPoolPrice;
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