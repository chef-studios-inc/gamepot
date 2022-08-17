// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract GameState {
  enum GameState { PREGAME, PLAYING, COMPLETE }

  address private contractCreator;

  mapping (uint => bool) public pregameGames;
  mapping (uint => bool) public playingGames;
  mapping (uint => bool) public completeGames;
  mapping (uint => bool) public existingGames;
  mapping (uint => address[]) public gamePlayersList;
  mapping (uint256 => bool) public gamePlayerCheck;

  constructor() {
    contractCreator = msg.sender;
  }

  function createGame(uint game_id) public {
    require(msg.sender == contractCreator, "this contract can only be called by its creator");
    require(existingGames[game_id] == false, "game_id already exists, please choose another");

    existingGames[game_id] = true;
    pregameGames[game_id] = true;
  } 

  function startGame(uint game_id, address[] calldata players) public {
    require(msg.sender == contractCreator, "this contract can only be called by its creator");
    require(existingGames[game_id] == true, "game_id doesn't exist");
    require(pregameGames[game_id] == true, "Can only start from PREGAME state");

    for(uint i = 0; i < players.length; i++) {
      uint256 lookupKey = getLookupKey(game_id, players[i]);
      if(!gamePlayerCheck[lookupKey]) {
        gamePlayerCheck[lookupKey] = true;
        gamePlayersList[game_id].push(players[i]);
      }
    }

    pregameGames[game_id] = false;
    playingGames[game_id] = true;
  }

  function completeGame(uint game_id) public {
    require(msg.sender == contractCreator, "this contract can only be called by its creator");
    require(existingGames[game_id] == true, "game_id doesn't exist");
    require(playingGames[game_id] == true, "Can only complete from PLAYING state");

    playingGames[game_id] = false;
    completeGames[game_id] = true;
  }

  function resetGame(uint game_id) public {
    require(msg.sender == contractCreator, "this contract can only be called by its creator");
    require(existingGames[game_id] == true, "game_id doesn't exist");
    require(completeGames[game_id] == true, "Can only reset from COMPLETE state");

    completeGames[game_id] = false;
    pregameGames[game_id] = true;
    clearGamePlayers(game_id);
  }

  function cancelGame(uint game_id) public {
    require(msg.sender == contractCreator, "this contract can only be called by its creator");
    require(existingGames[game_id] == true, "game_id doesn't exist");
    require(pregameGames[game_id] == false, "Can't cancel a PREGAME game");

    playingGames[game_id] = false;
    completeGames[game_id] = false;
    pregameGames[game_id] = true;
    clearGamePlayers(game_id);
  }

  function getGameState(uint game_id) public view returns (GameState) {
    require(msg.sender == contractCreator, "this contract can only be called by its creator");
    require(existingGames[game_id] == true, "game_id doesn't exist");

    if(pregameGames[game_id]) {
      return GameState.PREGAME;
    }

    if(playingGames[game_id]) {
      return GameState.PLAYING;
    }

    return GameState.COMPLETE;
  }

  function checkIfPlayerInGame(uint game_id, address addr) public view returns (bool) {
    require(msg.sender == contractCreator, "this contract can only be called by its creator");
    require(existingGames[game_id] == true, "game_id doesn't exist");
    return gamePlayerCheck[getLookupKey(game_id, addr)];
  }

  function validateLeaderboard(uint game_id, address[] calldata leaderboard) public view returns (bool) {
    require(msg.sender == contractCreator, "this contract can only be called by its creator");
    require(existingGames[game_id] == true, "game_id doesn't exist");

    if(gamePlayersList[game_id].length != leaderboard.length) {
      return false;
    }

    for(uint i = 0; i < leaderboard.length; i++) {
      if(!gamePlayerCheck[getLookupKey(game_id, leaderboard[i])]) {
        return false;
      }
    }
    return true;
  }

  function clearGamePlayers(uint game_id) private {
    address[] memory players = gamePlayersList[game_id];

    for(uint i = 0; i < players.length; i++) {
      gamePlayerCheck[getLookupKey(game_id, players[i])] = false;
    }

    delete gamePlayersList[game_id];
  }

  function getLookupKey(uint game_id, address addr) private pure returns (uint256) {
    return uint256(keccak256(abi.encode(game_id, addr)));
  }
}