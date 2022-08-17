// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./PrizePoolRoyaltySplit.sol";

struct PrizePoolSettings {
  PrizePoolRoyaltySplit[] royaltySplits;
  uint joinPoolPrice;
  uint topPercentOfPlayersPaidOut;
  uint firstPlaceMultiplier;
  uint totalRoyaltyPercent;
}