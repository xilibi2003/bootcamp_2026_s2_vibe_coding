// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MyToken1 is ERC20 {
    constructor() ERC20("MyToken1", "MTK1") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }
}
