// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract PrizePool {
  mapping (uint => bool) public existingPools;
  mapping (uint => ERC20) public poolCurrency;

  function createPool(uint pool_id, ERC20 currency) public {
    require(existingPools[pool_id] == false, "pool_id already exists, please choose another");
  } 

  function buyIn(uint pool_id, uint player) public {
  }

  function payOut(uint pool_id, uint firstPlaceMultiplier, uint basisPtsPaidOut) public {
  }

  function cashOut(uint pool_id, uint player) public {
  }
}