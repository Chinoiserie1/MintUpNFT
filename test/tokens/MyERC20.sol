// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MyERC20 is ERC20 {
  constructor() ERC20("TEST", "TST") {
    _mint(msg.sender, 10000 ether);
  }
}