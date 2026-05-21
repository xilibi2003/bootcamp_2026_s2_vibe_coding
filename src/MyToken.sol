// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC1363} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC1363.sol";

contract MyToken is ERC1363 {
    constructor(string memory symbol ) ERC20("EmmetTestToken", symbol) {
        _mint(msg.sender, 100000 * 10 ** decimals());
    }
}
