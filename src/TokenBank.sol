// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    function balanceOf(address account) external view returns (uint256);
}

contract TokenBank {
    IERC20 public immutable token;
    address public admin;

    mapping(address => uint256) public depositedAmount;

    event Deposited(
        address indexed user,
        uint256 amount,
        uint256 totalDeposited
    );
    event Withdrawn(address indexed admin, uint256 amount);

    modifier onlyAdmin() {
        require(msg.sender == admin, "TokenBank: caller is not admin");
        _;
    }

    constructor(address tokenAddress) {
        require(tokenAddress != address(0), "TokenBank: token is zero address");

        token = IERC20(tokenAddress);
        admin = msg.sender;
    }

    function deposit(uint256 amount) external {
        _deposit(msg.sender, amount);
    }

    function withdraw() external onlyAdmin {
        uint256 amount = token.balanceOf(address(this));
        require(amount > 0, "TokenBank: no token to withdraw");

        bool success = token.transfer(admin, amount);
        require(success, "TokenBank: transfer failed");

        emit Withdrawn(admin, amount);
    }

    function _deposit(address user, uint256 amount) internal {
        require(amount > 0, "TokenBank: amount must be greater than zero");

        bool success = token.transferFrom(user, address(this), amount);
        require(success, "TokenBank: transferFrom failed");

        depositedAmount[user] += amount;
        emit Deposited(user, amount, depositedAmount[user]);
    }
}

