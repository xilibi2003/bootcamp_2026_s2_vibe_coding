// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {VestingWallet} from "openzeppelin-contracts/contracts/finance/VestingWallet.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title TokenVesting
 * @dev Vesting contract based on OpenZeppelin's VestingWallet.
 * Cliff duration: 12 months.
 * Linear monthly vesting: 24 months.
 * Unlocks 1/24 of tokens monthly starting from month 13 (month 12 + 1 month).
 */
contract TokenVesting is VestingWallet {
    using SafeERC20 for IERC20;

    IERC20 public immutable vestingToken;
    uint256 public constant MONTH = 30 days;

    constructor(
        address beneficiary,
        address tokenAddress
    )
        VestingWallet(
            beneficiary,
            uint64(block.timestamp + 12 * MONTH), // Vesting starts after 12 months cliff
            uint64(24 * MONTH)                    // Vesting duration is 24 months
        )
    {
        require(tokenAddress != address(0), "TokenVesting: token is zero address");
        vestingToken = IERC20(tokenAddress);
    }

    /**
     * @dev Overloads release() to release the locked ERC20 vestingToken to the beneficiary.
     */
    function release() public override {
        // Releases the vestingToken using parent VestingWallet release logic
        release(address(vestingToken));
    }

    /**
     * @dev Overrides standard _vestingSchedule to implement monthly discrete step-unlock.
     * Before Month 12: 0.
     * At Month 12: 0.
     * Month 13: 1/24.
     * Month 14: 2/24.
     * ...
     * Month 36: 24/24 (100%).
     */
    function _vestingSchedule(
        uint256 totalAllocation,
        uint64 timestamp
    ) internal view override returns (uint256) {
        if (timestamp < start()) {
            return 0;
        }

        uint256 elapsed = timestamp - start();
        uint256 months = elapsed / MONTH;

        if (months >= 24) {
            return totalAllocation;
        }

        return (totalAllocation * months) / 24;
    }
}
