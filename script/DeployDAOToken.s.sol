// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseScript} from "./BaseScript.s.sol";
import {DAOToken} from "../src/DAOToken.sol";
import "forge-std/console.sol";

contract DeployDAOToken is BaseScript {
    function setUp() public override {
        super.setUp();
    }

    function run() external broadcaster returns (DAOToken token) {
        string memory name = "DAOToken";
        string memory symbol = "DAO";
        uint256 initialSupply = 1_000_000 * 10**18;

        token = new DAOToken(name, symbol, initialSupply);

        console.log("DAOToken deployed at:", address(token));
        saveContract("DAOToken", address(token));
    }
}
