// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Import this file to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/// @title GamePot
/// @author Neil Dwyer (neil@chefstudios.com)
/// @notice A simple contract that represents a game's state machine 
///         where users buy-in to a reward pool and a percentage gets
///         paid out to the top users with some percentage going to
///         the contract's owner
contract GamePot is AccessControl {
  enum GameState { PREGAME, PLAYING, COMPLETE }
  bytes32 public constant OWNER_ROLE = keccak256("OWNER");
  bytes32 public constant GAME_CONTROLLER_ROLE = keccak256("GAME_CONTROLLER");

  // settings 
  uint public constant firstPlaceAwardMultiplier = 2;
  uint public constant percentageOfPlayersAwarded = 40;
  uint public constant hostingFeePercentage = 10;
  uint public price;

  // state
  GameState public gameState = GameState.PREGAME;
  address[] public playersInGame;
  uint public playersInGameCount;
  mapping (address => bool) public playersInGameLookup;
  mapping (address => uint) public playerBalances;
  uint public playerBalanceTotal;

  constructor() {
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _setupRole(OWNER_ROLE, msg.sender);
    _setRoleAdmin(OWNER_ROLE, DEFAULT_ADMIN_ROLE);
  }

  /// @notice sets the buy-in price
  /// @param newPrice the new buy-in price in wei
  /// @dev requires OWNER role
  function setPrice(uint newPrice) public {
      require(hasRole(OWNER_ROLE, msg.sender), "Only an address with the OWNER role can do this");
      require(gameState == GameState.PREGAME, "Can only change the price from the PREGAME state");
      require(price != newPrice, "You are trying to set the same price");
      price = newPrice;
  }

  /// @notice adds an address that has permission to control the game
  /// @param addr - the game controller wallet address
  /// @dev requires OWNER role
  function addGameController(address addr) public {
      require(hasRole(OWNER_ROLE, msg.sender), "Only an address with the OWNER role can do this");
      grantRole(GAME_CONTROLLER_ROLE, addr);
  }

  /// @notice called by a game controller to start a game
  /// @param players - a list of wallets that are playing in this game
  /// @return - a tuple(bytes32[] wallets in game, bytes32[] wallets that didn't make it into game)
  /// @dev requires GAME_CONTROLLER role
  function startGame(address[] calldata players) public returns(address[] memory, address[] memory) {
      require(hasRole(GAME_CONTROLLER_ROLE, msg.sender), "Only an address with the GAME_CONTROLLER role can do this");
      require(gameState == GameState.PREGAME, "Can only start a game from the PREGAME state");

      uint inGameCount = 0;
      uint notEnoughBalanceCount = 0;
      for(uint i = 0; i < players.length; i++) {
        if(playerBalances[players[i]] < price) {
          notEnoughBalanceCount++;
          continue;
        }
        inGameCount++;
      }

      address[] memory inGame = new address[](inGameCount);
      address[] memory notEnoughBalance = new address[](notEnoughBalanceCount);

      uint inGameIdx = 0;
      uint notEnoughBalanceIdx = 0;
      for(uint i = 0; i < players.length; i++) {
        if(playerBalances[players[i]] < price) {
          notEnoughBalance[notEnoughBalanceIdx] = players[i];
          notEnoughBalanceIdx++;
          continue;
        }
        inGame[inGameIdx] = players[i];
        inGameIdx++;
        playerBalances[players[i]] -= price;
        playerBalanceTotal -= price;
        playersInGameLookup[players[i]] = true;
      }

      gameState = GameState.PLAYING;
      playersInGame = inGame;
      playersInGameCount = inGameCount;
      return (inGame, notEnoughBalance);
  }

  /// @notice called by a game controller to end a game
  /// @param leaderboard - a list of wallets in order of descending score
  /// @dev requires GAME_CONTROLLER role
  function endGame(address[] calldata leaderboard) public {
      require(hasRole(GAME_CONTROLLER_ROLE, msg.sender), "Only an address with the GAME_CONTROLLER role can do this");
      require(gameState == GameState.PLAYING, "Can only start a game from the PLAYING state");
      require(leaderboard.length > 0, "Must have some players in the leaderboard");

      uint prizePool = 0;

      // Figure out the prize pool
      for(uint i = 0; i < playersInGame.length; i++) {
        prizePool += price;
      }

      uint paidOut = 0;

      for(uint i = 0; i < leaderboard.length; i++) {
        if(!playersInGameLookup[leaderboard[i]]) {
          continue;
        }

        uint award = calculateAward(leaderboard.length, i, prizePool, paidOut);

        if(award > 0) {
          paidOut += award;
          playerBalances[leaderboard[i]] += award;
          playerBalanceTotal += award;
        }
      }

      clearPlayingPlayers();

      gameState = GameState.COMPLETE;
      return;
  }

  function cancelGame() public {
      require(hasRole(GAME_CONTROLLER_ROLE, msg.sender), "Only an address with the GAME_CONTROLLER role can do this");
      require(gameState == GameState.PLAYING, "Can only start a game from the PLAYING state");

      // refund user
      for(uint i = 0; i < playersInGame.length; i++) {
        playerBalances[playersInGame[i]] += price;
        playerBalanceTotal += price;
        clearPlayingPlayers();
      }

      gameState = GameState.PREGAME;
      return;
  }

  function resetGame() public {
    require(hasRole(GAME_CONTROLLER_ROLE, msg.sender), "Only an address with the GAME_CONTROLLER role can do this");
    require(gameState == GameState.PLAYING, "Can only start a game from the PLAYING state");
    gameState = GameState.PREGAME;
  }

  function getBalance() public view returns(uint) {
    return playerBalances[msg.sender];
  }

  /// @notice called by users to buy in to games
  function buyIn() public payable {
    require(msg.value > 0, "Can't buy in with nothing");
    playerBalances[msg.sender] += msg.value;
    playerBalanceTotal += msg.value;
  }

  function cashOut() public {
    uint balance = playerBalances[msg.sender];
    require(balance > 0, "Your balance is empty");

    playerBalances[msg.sender] = 0;
    playerBalanceTotal -= balance;

    if(!payable(msg.sender).send(balance)) {
      playerBalances[msg.sender] = balance;
      playerBalanceTotal += balance;
    }
  }

  function takeProfits() public {
    require(hasRole(OWNER_ROLE, msg.sender), "Only an address with the OWNER role can do this");
    uint profits = address(this).balance - playerBalanceTotal;
    payable(msg.sender).transfer(profits);
  }

  function clearPlayingPlayers() private {
    for(uint i = 0; i < playersInGame.length; i++) {
      playersInGameLookup[playersInGame[i]] = false;
    }
    delete playersInGame;
    playersInGameCount = 0;
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
  function calculateAward(uint leaderboardLength, uint leaderboardIndex, uint prizePool, uint currentPaidOut) private view returns(uint) {
    uint lastAwardedIndexTimes100 = leaderboardLength * percentageOfPlayersAwarded;
    uint maxPayout = prizePool * (100 - hostingFeePercentage) / 100;
    uint multiplerReductionTimesPriceDividedBy100 = firstPlaceAwardMultiplier * leaderboardIndex * price / lastAwardedIndexTimes100;

    uint award;
    if(firstPlaceAwardMultiplier * price > multiplerReductionTimesPriceDividedBy100 * 100) {
      award = (firstPlaceAwardMultiplier * price - multiplerReductionTimesPriceDividedBy100 * 100);
      // make sure the contract is profitable
      if(award + currentPaidOut > maxPayout) {
        award = maxPayout - currentPaidOut;
      }
    } else {
      // make sure the contract is profitable, award the scraps if possible
      if(currentPaidOut + firstPlaceAwardMultiplier * price > maxPayout + multiplerReductionTimesPriceDividedBy100 * 100) {
        award = maxPayout - currentPaidOut;
      }
    }

    return award;
  }
}
