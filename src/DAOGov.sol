// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Governor} from "openzeppelin-contracts/contracts/governance/Governor.sol";
import {GovernorCountingSimple} from "openzeppelin-contracts/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorVotes} from "openzeppelin-contracts/contracts/governance/extensions/GovernorVotes.sol";
import {IVotes} from "openzeppelin-contracts/contracts/governance/utils/IVotes.sol";

/**
 * @title DAOGov
 * @dev Governance contract based on OpenZeppelin's Governor, GovernorCountingSimple, and GovernorVotes.
 */
contract DAOGov is Governor, GovernorCountingSimple, GovernorVotes {
    constructor(IVotes _token)
        Governor("DAOGov")
        GovernorVotes(_token)
    {}

    /**
     * @notice Delay between proposal creation and start of voting (in blocks).
     */
    function votingDelay() public pure override returns (uint256) {
        return 1; // 1 block delay
    }

    /**
     * @notice Duration of the voting phase (in blocks).
     */
    function votingPeriod() public pure override returns (uint256) {
        return 10; // 10 blocks voting period
    }

    /**
     * @notice Voting power quorum required for a proposal to succeed.
     */
    function quorum(uint256 /* timepoint */) public pure override returns (uint256) {
        return 10_000 * 10**18; // 10,000 tokens required for quorum
    }
}
