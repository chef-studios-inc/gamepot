// SPDX-License-Identifier: UNLICENSED
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestERC20 is ERC20 {
  constructor() ERC20("Test ERC20", "TERC") {
    _mint(msg.sender, 1000000000 ether);
  }
}