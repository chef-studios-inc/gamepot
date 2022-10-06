// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract GameModeration {
  address private contractCreator;

  mapping (uint => address) public gameIdToOwner;
  mapping (uint => bool) public existingGameIds;
  mapping (uint256 => bool) public gameMods;

  constructor() {
    contractCreator = msg.sender;
  }

  function createGame(uint game_id, address caller) public {
    require(msg.sender == contractCreator, "this contract can only be called by its creator");
    require(existingGameIds[game_id] == false, "game already exists");
    existingGameIds[game_id] = true;
    gameIdToOwner[game_id] = caller;
  }

  function setOwner(uint game_id, address owner, address caller) public {
    require(msg.sender == contractCreator, "this contract can only be called by its creator");
    require(existingGameIds[game_id] == true, "game doesn't exist");
    require(gameIdToOwner[game_id] == caller, "only an owner can set a new owner");
    gameIdToOwner[game_id] = owner;
  }

  function addMod(uint game_id, address mod, address caller) public {
    require(msg.sender == contractCreator, "this contract can only be called by its creator");
    require(existingGameIds[game_id] == true, "game doesn't exist");
    require(gameIdToOwner[game_id] == caller, "only an owner can add a mod");
    gameMods[getModLookupKey(game_id, mod)] = true;
  }

  function removeMod(uint game_id, address mod, address caller) public {
    require(msg.sender == contractCreator, "this contract can only be called by its creator");
    require(existingGameIds[game_id] == true, "game doesn't exist");
    require(gameIdToOwner[game_id] == caller, "only an owner can remove a mod");
    gameMods[getModLookupKey(game_id, mod)] = false;
  }

  function isModOrOwner(uint game_id, address addr) public view returns (bool) {
    require(msg.sender == contractCreator, "this contract can only be called by its creator");
    require(existingGameIds[game_id] == true, "game doesn't exist");
    if(gameIdToOwner[game_id] == addr) {
      return true;
    }

    if(gameMods[getModLookupKey(game_id, addr)]) {
      return true;
    }

    return false;
  }

  function isOwner(uint game_id, address addr) public view returns (bool) {
    require(msg.sender == contractCreator, "this contract can only be called by its creator");
    require(existingGameIds[game_id] == true, "game doesn't exist");
    return gameIdToOwner[game_id] == addr;
  }

  function getOwner(uint game_id) public view returns(address) {
    return gameIdToOwner[game_id];
  }

  function getModLookupKey(uint game_id, address addr) private pure returns (uint256) {
    return uint256(keccak256(abi.encode(game_id, addr)));
  }
}