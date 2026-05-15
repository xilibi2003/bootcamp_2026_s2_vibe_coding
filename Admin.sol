// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Bank.sol";

contract Admin {
    address public owner;

    event OwnerTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    event BankWithdrawal(address indexed bank, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Admin: caller is not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    receive() external payable {}

    // withdraw() {}

    function transferOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Admin: new owner is zero address");

        address previousOwner = owner;
        owner = newOwner;

        emit OwnerTransferred(previousOwner, newOwner);
    }

    function adminWithdraw(IBank bank) external onlyOwner {
        require(
            bank.admin() == address(this),
            "Admin: contract is not bank admin"
        );

        uint256 balanceBefore = address(this).balance;
        bank.withdraw();
        uint256 amount = address(this).balance - balanceBefore;

        emit BankWithdrawal(address(bank), amount);
    }
}
