// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract MyPermitToken is ERC20, ERC20Permit {
    constructor() ERC20("MyPermitToken", "MPT2") ERC20Permit("MyPermitToken") {
        _mint(msg.sender, 100000 * 10 ** decimals());
    }
}
