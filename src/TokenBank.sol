// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC1363Receiver} from "openzeppelin-contracts/contracts/interfaces/IERC1363Receiver.sol";

contract TokenBank is IERC1363Receiver {
    using SafeERC20 for IERC20;

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
        require(amount > 0, "TokenBank: amount must be greater than zero");

        token.safeTransferFrom(msg.sender, address(this), amount);

        _recordDeposit(msg.sender, amount);
    }

    function withdraw() external onlyAdmin {
        uint256 amount = token.balanceOf(address(this));
        require(amount > 0, "TokenBank: no token to withdraw");

        token.safeTransfer(admin, amount);

        emit Withdrawn(admin, amount);
    }

    function onTransferReceived(
        address,
        address from,
        uint256 value,
        bytes calldata
    ) external returns (bytes4) {
        require(msg.sender == address(token), "TokenBank: unsupported token");
        require(value > 0, "TokenBank: amount must be greater than zero");

        _recordDeposit(from, value);

        return IERC1363Receiver.onTransferReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return
            interfaceId == type(IERC1363Receiver).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }

    function _recordDeposit(address user, uint256 amount) internal {
        depositedAmount[user] += amount;
        emit Deposited(user, amount, depositedAmount[user]);
    }
}
