// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract GameState {
  enum GameState { PREGAME, PLAYING, COMPLETE }

  mapping (uint => bool) public pregameGames;
  mapping (uint => bool) public playingGames;
  mapping (uint => bool) public completeGames;
  mapping (uint => bool) public existingGames;
  mapping (uint => uint[]) public gamePlayersList;
  mapping (uint256 => bool) public gamePlayerCheck;

  function createGame(uint game_id) public {
    require(existingGames[game_id] == false, "game_id already exists, please choose another");

    existingGames[game_id] = true;
    pregameGames[game_id] = true;
  } 

  function startGame(uint game_id, uint[] calldata players) public {
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
    require(existingGames[game_id] == true, "game_id doesn't exist");
    require(playingGames[game_id] == true, "Can only complete from PLAYING state");

    playingGames[game_id] = false;
    completeGames[game_id] = true;
  }

  function resetGame(uint game_id) public {
    require(existingGames[game_id] == true, "game_id doesn't exist");
    require(completeGames[game_id] == true, "Can only reset from COMPLETE state");

    completeGames[game_id] = false;
    pregameGames[game_id] = true;
    clearGamePlayers(game_id);
  }

  function cancelGame(uint game_id) public {
    require(existingGames[game_id] == true, "game_id doesn't exist");
    require(pregameGames[game_id] == false, "Can't cancel a PREGAME game");

    playingGames[game_id] = false;
    completeGames[game_id] = false;
    pregameGames[game_id] = true;
  }

  function getGameState(uint game_id) public view returns (GameState) {
    require(existingGames[game_id] == true, "game_id doesn't exist");

    if(pregameGames[game_id]) {
      return GameState.PREGAME;
    }

    if(playingGames[game_id]) {
      return GameState.PLAYING;
    }

    if(completeGames[game_id]) {
      return GameState.COMPLETE;
    }

    require(false, "game_id is in a bad state, there is a bug in this contract");
    return GameState.PREGAME;
  }

  function checkIfPlayerInGame(uint game_id, uint addr) public view returns (bool) {
    require(existingGames[game_id] == true, "game_id doesn't exist");
    return gamePlayerCheck[getLookupKey(game_id, addr)];
  }

  function clearGamePlayers(uint game_id) private {
    uint[] memory players = gamePlayersList[game_id];

    for(uint i = 0; i < players.length; i++) {
      gamePlayerCheck[getLookupKey(game_id, players[i])] = false;
    }

    delete gamePlayersList[game_id];
  }

  function getLookupKey(uint game_id, uint addr) private pure returns (uint256) {
    return uint256(keccak256(abi.encode(game_id, addr)));
  }
}