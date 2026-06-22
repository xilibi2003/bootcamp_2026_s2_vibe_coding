// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {
    SafeERC20
} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * @title OptionToken
 * @dev A call option token contract conforming to the ERC20 standard.
 * It is collateralized 1:1 by native ETH, and can be exercised using USDT.
 */
contract OptionToken is ERC20, Ownable {
    using SafeERC20 for IERC20;

    // Strike price: amount of USDT (in USDT base units, e.g. 6 decimals) required per 1 ETH (10^18 OptionToken).
    uint256 public immutable strikePrice;

    // Expiry timestamp (seconds)
    uint256 public immutable expiry;

    // USDT contract address
    IERC20 public immutable usdt;

    // Exercise window duration (24 hours, i.e., "到期日当天")
    uint256 public constant EXERCISE_WINDOW = 24 * 60 * 60;

    event Mint(address indexed minter, uint256 amount);
    event Exercise(
        address indexed user,
        uint256 optionAmount,
        uint256 usdtAmount
    );
    event ExpiredBurn(
        address indexed owner,
        uint256 ethAmount,
        uint256 usdtAmount
    );
    event CleanedExpiredToken(address indexed account, uint256 amount);

    constructor(
        uint256 _strikePrice,
        uint256 _expiry,
        address _usdt
    ) ERC20("Option ETH Call Token", "OPT-ETH") Ownable(msg.sender) {
        require(_strikePrice > 0, "Strike price must be greater than 0");
        require(_expiry > block.timestamp, "Expiry must be in the future");
        require(_usdt != address(0), "Invalid USDT address");

        strikePrice = _strikePrice;
        expiry = _expiry;
        usdt = IERC20(_usdt);
    }

    /**
     * @dev Mint OptionToken by locking native ETH 1:1.
     * Accessible only by the project owner.
     */
    function mint() external payable onlyOwner {
        require(msg.value > 0, "Must send ETH to mint");
        require(block.timestamp < expiry, "Cannot mint after expiry");

        _mint(msg.sender, msg.value);
        emit Mint(msg.sender, msg.value);
    }

    /**
     * @dev Exercise the option.
     * The caller pays `usdtAmount = amount * strikePrice / 1e18` in USDT,
     * burns their `amount` of OptionToken, and receives `amount` of native ETH.
     * Can only be called on the expiry day: block.timestamp in [expiry, expiry + 24 hours).
     */
    function exercise(uint256 amount) external {
        require(
            block.timestamp >= expiry,
            "Exercise window has not opened yet"
        );
        require(
            block.timestamp < expiry + EXERCISE_WINDOW,
            "Exercise window has closed"
        );
        require(amount > 0, "Amount must be greater than 0");
        require(
            balanceOf(msg.sender) >= amount,
            "Insufficient option token balance"
        );

        // Calculate USDT payment amount.
        // amount has 18 decimals, strikePrice has USDT decimals.
        // usdtAmount = (amount * strikePrice) / 10**18
        uint256 usdtAmount = (amount * strikePrice) / 1e18;
        require(usdtAmount > 0, "Calculated USDT amount is 0");

        // Burn option tokens from user
        _burn(msg.sender, amount);

        // Collect USDT strike price payment
        usdt.safeTransferFrom(msg.sender, address(this), usdtAmount);

        // Send underlying ETH collateral to user
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "ETH transfer failed");

        emit Exercise(msg.sender, amount, usdtAmount);
    }

    /**
     * @dev Expired cleanup.
     * Accessible only by the project owner.
     * After the exercise window has passed, the owner can reclaim any remaining ETH
     * collateral and accumulated USDT. The remaining option tokens held by the owner
     * are burned.
     */
    function burnExpired() external onlyOwner {
        require(
            block.timestamp >= expiry + EXERCISE_WINDOW,
            "Exercise window is still open"
        );

        // Burn owner's own remaining option tokens, if any
        uint256 ownerBalance = balanceOf(msg.sender);
        if (ownerBalance > 0) {
            _burn(msg.sender, ownerBalance);
        }

        uint256 ethBalance = address(this).balance;
        uint256 usdtBalance = usdt.balanceOf(address(this));

        // Withdraw underlying ETH collateral
        if (ethBalance > 0) {
            (bool success, ) = msg.sender.call{value: ethBalance}("");
            require(success, "ETH transfer failed");
        }

        // Withdraw USDT payments received from exercises
        if (usdtBalance > 0) {
            usdt.safeTransfer(msg.sender, usdtBalance);
        }

        emit ExpiredBurn(msg.sender, ethBalance, usdtBalance);
    }

    /**
     * @dev Burn option tokens after they have expired from any account to clean up
     * the dead tokens and set total supply to 0.
     * Since the exercise window is over, these tokens are permanently worthless and unusable.
     * Anyone can trigger this cleanup for any account once expired.
     */
    function cleanExpiredToken(address account) external {
        require(
            block.timestamp >= expiry + EXERCISE_WINDOW,
            "Exercise window is still open"
        );
        uint256 balance = balanceOf(account);
        require(balance > 0, "No balance to clean");
        _burn(account, balance);
        emit CleanedExpiredToken(account, balance);
    }

    /**
     * @dev Fallback to receive ETH. Only allows receiving ETH if it's sent via mint().
     * Direct ETH transfers without calling mint() are rejected to avoid locking ETH.
     */
    receive() external payable {
        revert("Direct deposits not allowed. Use mint()");
    }
}
