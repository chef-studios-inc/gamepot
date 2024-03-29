// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract Credits {
  address private contractCreator;
  bool public canWithdraw;
  uint royaltyPercentage;

  struct PoolPayout {
    address recipient;
    uint amount;
  }

  struct AddedCredits {
    address caller;
    ERC20 currency;
    uint amount;
  }

  struct PlayerSignature {
    uint cost;
    uint pool_id;
  }

  event PoolPaidOut(PoolPayout[] poolPayouts, ERC20 currency);

  uint256 chain_id;

	mapping (uint256 => uint) poolPaidBalances;
	mapping (uint256 => uint) creditBalances;
  mapping (uint256 => uint) winningsBalances;

  mapping (uint256 => ERC20) poolCurrency;
  mapping (uint256 => bool) poolMembers;
  mapping (uint256 => uint[]) poolPayoutWeights;
  mapping (uint256 => uint) poolCosts;
  mapping (uint256 => uint) poolMemberLastIndex;
  mapping (uint256 => address) poolMemberLookup;
  mapping (uint256 => bool) poolRefunded;
  mapping (uint256 => uint) poolBoost;

  mapping (address => uint) public referralRoyaltySplits; // receiver => percentage
  mapping (address => address) public referralReceivers; // sender => receiver

  mapping (ERC20 => uint) contractProfits;
  mapping (ERC20 => uint) contractBoostBalance;

  constructor() {
    contractCreator = msg.sender;
    uint256 id;
    assembly {
      id := chainid()
    }
    chain_id = id;
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

  function withrawCredits(address caller, ERC20 currency) public {
    require(msg.sender == contractCreator, "this contract can only be called by its creator");
    require(canWithdraw, "credit withdraws are disabled, they are only enabled in the event of a total contract failure/upgrade");
    uint256 key = getAddressCurrencyKey(caller, currency);
    uint amount = creditBalances[key];
    creditBalances[key] = 0;
    if(!currency.transfer(caller, amount)) {
      creditBalances[key] = amount;
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

  function takeWinnings(address caller, ERC20 currency) public {
    uint256 key = getAddressCurrencyKey(caller, currency);
    uint amount = winningsBalances[key];
    winningsBalances[key] = 0;
    if(!currency.transfer(caller, amount)) {
      winningsBalances[key] = amount;
    }
  }

  // Prize Pool

  function startPrizePool(uint256 pool_id, ERC20 currency, uint[] calldata payoutWeights, address[] calldata playersWallets, uint cost, uint boost) public {
    require(msg.sender == contractCreator, "this contract can only be called by its creator");
    require(address(poolCurrency[pool_id]) == address(0), "pool_id already exists, please choose another");
    require(contractBoostBalance[currency] >= boost, "not enough boost balance");

    contractBoostBalance[currency] -= boost;
    poolCurrency[pool_id] = currency;
    poolPayoutWeights[pool_id] = payoutWeights;
    poolCosts[pool_id] = cost;
    poolBoost[pool_id] = boost;

    for(uint i = 0; i < playersWallets.length; i++) {
      joinPrizePool(playersWallets[i], pool_id);
    }
  } 

  function joinPrizePool(address caller, uint256 pool_id) private returns (bool) {
    uint256 addressCurrencyKey = getAddressCurrencyKey(caller, poolCurrency[pool_id]);
    uint costs = poolCosts[pool_id];
    uint creditBalance = creditBalances[addressCurrencyKey];
    uint winningBalances = winningsBalances[addressCurrencyKey];

    if(winningBalances + creditBalance < costs) {
      return false;
    }

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

    return true;
  }

  function isJoined(address caller, uint pool_id) public view returns (bool) {
    require(msg.sender == contractCreator, "this contract can only be called by its creator");
    return poolMembers[getAddressCurrencyPoolIdKey(caller, poolCurrency[pool_id], pool_id)];
  }

  function payoutPrizePool(uint256 pool_id, address[] calldata leaderboard) public {
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

  function refundPool(uint256 pool_id) public {
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
    currency.transfer(caller, contractProfits[currency]);
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

  function setCanWithdraw(bool cd) public {
    require(msg.sender == contractCreator, "this contract can only be called by its creator");
    canWithdraw = cd;
  }

  // Tuple key generation
  function getPoolMemberIndexKey(uint256 pool, uint index) private pure returns (uint256) {
    return uint256(keccak256(abi.encodePacked(pool, index)));
  }

  function getAddressCurrencyKey(address addr, ERC20 currency) private pure returns (uint256) {
    return uint256(keccak256(abi.encodePacked(addr, currency)));
  }

  function getAddressCurrencyPoolIdKey(address addr, ERC20 currency, uint256 pool_id) private pure returns (uint256) {
    return uint256(keccak256(abi.encodePacked(addr, currency, pool_id)));
  }
}