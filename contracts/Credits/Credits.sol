// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";

contract Credits {
  address private contractCreator;
  bool public canWithdraw;
  uint royaltyPercentage;

  struct PoolPayout {
    address recipient;
    uint amount;
  }

  event PoolPaidOut(PoolPayout[] poolPayouts, ERC20 currency);

	mapping (uint256 => uint) poolPaidBalances;
	mapping (uint256 => uint) creditBalances;
  mapping (uint256 => uint) winningsBalances;

  mapping (uint => ERC20) poolCurrency;
  mapping (uint256 => bool) poolMembers;
  mapping (uint256 => uint[]) poolPayoutWeights;
  mapping (uint => uint) poolCosts;
  mapping (uint => uint) poolMemberLastIndex;
  mapping (uint256 => address) poolMemberLookup;
  mapping (uint256 => bool) poolRefunded;
  mapping (uint => uint) poolBoost;

  mapping (address => uint) public referralRoyaltySplits; // receiver => percentage
  mapping (address => address) public referralReceivers; // sender => receiver

  mapping (ERC20 => uint) contractProfits;
  mapping (ERC20 => uint) contractBoostBalance;

  constructor() {
    contractCreator = msg.sender;
  }

  // Credit Methods
  function addCreditsAndSetReferralReceiver(address caller, ERC20 currency, uint amount, address recipient, uint royaltySplitPercentage) public {
    require(msg.sender == contractCreator, "this contract can only be called by its creator");
    require(royaltySplitPercentage >= 0 && royaltySplitPercentage <= 100, "royalty percentage must be between 0 and 100"); 

    // only allow setting referral receiver if there isn't one already 
    if(recipient != address(0)) {
      referralRoyaltySplits[recipient] = royaltySplitPercentage;
      referralReceivers[caller] = recipient;
    }

    addCredits(caller, currency, amount);
  }

  function addCredits(address caller, ERC20 currency, uint amount) public {
    require(msg.sender == contractCreator, "this contract can only be called by its creator");
    uint256 key = getAddressCurrencyKey(caller, currency);

    if(currency.transferFrom(caller, address(this), amount)) {
      // pay out referral royalty
      address receiver = referralReceivers[caller];
      uint totalRoyaltyAmount = amount * royaltyPercentage / 100;
      uint creditAmount = amount - totalRoyaltyAmount;
      uint referralRoyaltyAmount = 0;
      if(receiver != address(0)) {
        uint royaltySplitPercentage = referralRoyaltySplits[receiver];
        referralRoyaltyAmount =  totalRoyaltyAmount * royaltySplitPercentage / 100;
        creditBalances[getAddressCurrencyKey(receiver, currency)] += referralRoyaltyAmount;
      }
      contractProfits[currency] += (totalRoyaltyAmount - referralRoyaltyAmount);
      creditBalances[key] += creditAmount;
    }
  }

  function getCreditBalance(address caller, ERC20 currency) public view returns (uint) {
    uint256 key = getAddressCurrencyKey(caller, currency);
    return creditBalances[key];
  }

  function getWinningBalance(address caller, ERC20 currency) public view returns (uint) {
    uint256 key = getAddressCurrencyKey(caller, currency);
    return winningsBalances[key];
  }

  function takeWinings(address caller, ERC20 currency) public {
    uint256 key = getAddressCurrencyKey(caller, currency);
    uint amount = winningsBalances[key];
    winningsBalances[key] = 0;
    currency.transfer(caller, amount);
  }

  // Prize Pool

  function startPrizePool(uint pool_id, ERC20 currency, uint[] calldata payoutWeights, uint cost, uint boost) public {
    require(msg.sender == contractCreator, "this contract can only be called by its creator");
    require(address(poolCurrency[pool_id]) == address(0), "pool_id already exists, please choose another");
    require(contractBoostBalance[currency] >= boost, "not enough boost balance");

    contractBoostBalance[currency] -= boost;
    poolCurrency[pool_id] = currency;
    poolPayoutWeights[pool_id] = payoutWeights;
    poolCosts[pool_id] = cost;
    poolBoost[pool_id] = boost;
  } 

  function joinPrizePool(address caller, uint pool_id) public {
    require(msg.sender == contractCreator, "this contract can only be called by its creator");
    require(address(poolCurrency[pool_id]) != address(0), "pool_id doesn't exist");

    uint256 addressCurrencyKey = getAddressCurrencyKey(caller, poolCurrency[pool_id]);
    uint costs = poolCosts[pool_id];
    uint creditBalance = creditBalances[addressCurrencyKey];
    uint winningBalances = winningsBalances[addressCurrencyKey];

    require(winningBalances + creditBalance >= costs, "not enough credits to join pool");

    if(creditBalance < costs) {
      winningsBalances[addressCurrencyKey] = creditBalance + winningBalances - costs;
      creditBalances[addressCurrencyKey] = 0;
    } else {
      creditBalances[addressCurrencyKey] -= costs;
    }

    poolPaidBalances[addressCurrencyKey] += costs;
    poolMembers[getAddressCurrencyPoolIdKey(caller, poolCurrency[pool_id], pool_id)] = true;
    poolMemberLookup[getPoolMemberIndexKey(pool_id, poolMemberLastIndex[pool_id])] = caller;
    poolMemberLastIndex[pool_id]++;
  }

  function payoutPrizePool(uint pool_id, address[] calldata leaderboard) public {
    require(msg.sender == contractCreator, "this contract can only be called by its creator");
    require(address(poolCurrency[pool_id]) != address(0), "pool_id doesn't exist");

    uint[] memory workingSpace = poolPayoutWeights[pool_id];
    uint weightsSum = 0;
    uint pool = poolCosts[pool_id] * leaderboard.length + poolBoost[pool_id];
    uint howManyWeightsToUse = leaderboard.length > workingSpace.length ? workingSpace.length : leaderboard.length;

    for(uint i = 0; i < howManyWeightsToUse; i++) {
      weightsSum += workingSpace[i];
      workingSpace[i] *= pool;
    }

    PoolPayout[] memory poolPayouts = new PoolPayout[](leaderboard.length);

    for(uint i = 0; i < leaderboard.length; i++) {
      uint256 addressCurrencyKey = getAddressCurrencyKey(leaderboard[i], poolCurrency[pool_id]);
      uint256 addressCurrencyPoolKey = getAddressCurrencyPoolIdKey(leaderboard[i], poolCurrency[pool_id], pool_id);
      if(!poolMembers[addressCurrencyPoolKey]) {
        console.log("Not in pool");
        continue;
      }

      uint payout =0;
      if(i < workingSpace.length) {
        payout = workingSpace[i] / weightsSum;
      }

      winningsBalances[addressCurrencyKey] += payout;
      poolPayouts[i] = PoolPayout(leaderboard[i], payout);
    }

    emit PoolPaidOut(poolPayouts, poolCurrency[pool_id]);
  }

  function refundPool(uint pool_id) public {
    require(msg.sender == contractCreator, "this contract can only be called by its creator");
    require(address(poolCurrency[pool_id]) != address(0), "pool_id doesn't exist");
    require(!poolRefunded[pool_id], "pool already refunded");

    poolRefunded[pool_id] = true;

    for(uint i = 0; i < poolMemberLastIndex[pool_id]; i++) {
      address member = poolMemberLookup[getPoolMemberIndexKey(pool_id, i)];
      uint256 addressCurrencyPoolKey = getAddressCurrencyPoolIdKey(member, poolCurrency[pool_id], pool_id);
      uint256 addressCurrencyKey = getAddressCurrencyKey(member, poolCurrency[pool_id]);
      creditBalances[addressCurrencyKey] += poolPaidBalances[addressCurrencyPoolKey];
      poolPaidBalances[addressCurrencyPoolKey] = 0;
    }
  }

  // Admin Methods
  function setRoyaltyPercentage(uint percentage) public {
    require(msg.sender == contractCreator, "this contract can only be called by its creator");
    require(percentage >= 0 && percentage <= 100, "royalty percentage must be between 0 and 100"); 
    royaltyPercentage = percentage;
  }

  function takeProfits(address caller, ERC20 currency) public {
    require(msg.sender == contractCreator, "this contract can only be called by its creator");
    uint amount = currency.balanceOf(address(this));
    currency.transfer(caller, amount);
  }

  function getProfits(ERC20 currency) public view returns (uint) {
    return contractProfits[currency];
  }

  function approveBoostWallet(address caller, ERC20 currency, uint amount) public {
    require(msg.sender == contractCreator, "this contract can only be called by its creator");
    currency.approve(caller, amount);
  }

  function addToBoostBalance(address caller, ERC20 currency, uint amount) public {
    require(msg.sender == contractCreator, "this contract can only be called by its creator");
    if(currency.transferFrom(caller, address(this), amount)) {
      contractBoostBalance[currency] += amount;
    }
  }

  function moveProfitsToBoost(ERC20 currency, uint amount) public {
    require(msg.sender == contractCreator, "this contract can only be called by its creator");
    require(contractProfits[currency] >= amount, "not enough profits");
    contractProfits[currency] -= amount;
    contractBoostBalance[currency] += amount;
  }

  // Tuple key generation
  function getPoolMemberIndexKey(uint pool, uint index) private pure returns (uint256) {
    return uint256(keccak256(abi.encodePacked(pool, index)));
  }

  function getAddressCurrencyKey(address addr, ERC20 currency) private pure returns (uint256) {
    return uint256(keccak256(abi.encodePacked(addr, currency)));
  }

  function getAddressCurrencyPoolIdKey(address addr, ERC20 currency, uint pool_id) private pure returns (uint256) {
    return uint256(keccak256(abi.encodePacked(addr, currency, pool_id)));
  }

  function getSenderReceiverKey(uint sender, uint receiver) private pure returns (uint256) {
    return uint256(keccak256(abi.encodePacked(sender, receiver)));
  }
}