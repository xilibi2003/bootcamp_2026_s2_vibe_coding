// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AutomationCompatibleInterface} from "./interfaces/AutomationCompatibleInterface.sol";
import {TokenBank} from "./TokenBank.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract TokenBankUpkeep is AutomationCompatibleInterface {
    TokenBank public immutable tokenBank;

    constructor(address _tokenBank) {
        require(_tokenBank != address(0), "TokenBankUpkeep: tokenBank is zero address");
        tokenBank = TokenBank(_tokenBank);
    }

    function checkUpkeep(
        bytes calldata /* checkData */
    ) external view override returns (bool upkeepNeeded, bytes memory performData) {
        IERC20 token = tokenBank.token();
        uint256 balance = token.balanceOf(address(tokenBank));
        
        // 当存款超过 100 个时 (100 * 10^18)
        if (balance > 100 * 10**18) {
            upkeepNeeded = true;
        }
        
        return (upkeepNeeded, "");
    }

    function performUpkeep(
        bytes calldata /* performData */
    ) external override {
        IERC20 token = tokenBank.token();
        uint256 balance = token.balanceOf(address(tokenBank));
        
        // Re-verify the upkeep condition to avoid front-running or incorrect execution
        require(balance > 100 * 10**18, "TokenBankUpkeep: balance must be greater than 100 tokens");
        
        tokenBank.collect();
    }
}
