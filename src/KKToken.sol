// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

contract KKToken is ERC20, Ownable {
    constructor() ERC20("KKToken", "KK") Ownable(msg.sender) {}

    /**
     * @dev Mints KKTokens to a specific address. Restrictable to the StakingPool contract.
     * @param to The address of the recipient.
     * @param amount The amount of tokens to mint.
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
