// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title RebaseToken
 * @dev An ERC20 token that implements rebasing for deflation.
 * The total supply decreases by 1% every 365 days (compounded).
 * Users' balances deflate proportionally.
 */
contract RebaseToken is IERC20, IERC20Metadata {
    string private _name;
    string private _symbol;
    uint8 private constant _decimals = 18;

    uint256 private _totalSupply;
    uint256 private _totalShares;

    mapping(address => uint256) private _shares;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 public lastRebaseTime;
    uint256 public constant REBASE_INTERVAL = 365 days;

    event Rebase(uint256 indexed timestamp, uint256 totalSupply);

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;

        // Initial supply of 10,000,000 tokens with 18 decimals
        uint256 initialSupply = 10_000_000 * 10**uint256(_decimals);
        _totalSupply = initialSupply;
        _totalShares = initialSupply;
        _shares[msg.sender] = initialSupply;

        lastRebaseTime = block.timestamp;

        emit Transfer(address(0), msg.sender, initialSupply);
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals.
     */
    function decimals() public pure override returns (uint8) {
        return _decimals;
    }

    /**
     * @dev Returns the current total supply of tokens, calculated dynamically based on time elapsed.
     */
    function totalSupply() public view override returns (uint256) {
        uint256 timePassed = block.timestamp - lastRebaseTime;
        uint256 yearsPassed = timePassed / REBASE_INTERVAL;
        uint256 currentSupply = _totalSupply;
        
        for (uint256 i = 0; i < yearsPassed; i++) {
            currentSupply = (currentSupply * 99) / 100;
        }
        return currentSupply;
    }

    /**
     * @dev Returns the token balance of `account`, calculated dynamically based on time elapsed.
     */
    function balanceOf(address account) public view override returns (uint256) {
        return sharesToToken(_shares[account]);
    }

    /**
     * @dev Performs the rebase deflation logic if enough time has passed.
     * Anyone can call this function.
     */
    function rebase() public returns (uint256) {
        uint256 timePassed = block.timestamp - lastRebaseTime;
        uint256 yearsPassed = timePassed / REBASE_INTERVAL;

        if (yearsPassed > 0) {
            uint256 currentSupply = _totalSupply;
            for (uint256 i = 0; i < yearsPassed; i++) {
                currentSupply = (currentSupply * 99) / 100;
            }
            _totalSupply = currentSupply;
            lastRebaseTime += yearsPassed * REBASE_INTERVAL;

            emit Rebase(block.timestamp, currentSupply);
        }
        return _totalSupply;
    }

    /**
     * @dev Transfers `amount` tokens to `to`.
     */
    function transfer(address to, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    /**
     * @dev Returns the remaining number of tokens that `spender` is allowed to spend on behalf of `owner`.
     */
    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev Approves `spender` to spend `amount` tokens.
     */
    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    /**
     * @dev Transfers `amount` tokens from `from` to `to` using allowance.
     */
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Converts token amount to shares.
     */
    function tokenToShares(uint256 amount) public view returns (uint256) {
        uint256 currentSupply = totalSupply();
        if (currentSupply == 0) return 0;
        return (amount * _totalShares) / currentSupply;
    }

    /**
     * @dev Converts shares to token amount.
     */
    function sharesToToken(uint256 shares) public view returns (uint256) {
        if (_totalShares == 0) return 0;
        return (shares * totalSupply()) / _totalShares;
    }

    /**
     * @dev Internal transfer function. Performs state-updating rebase first.
     */
    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        // Keep storage updated before modifying balances
        rebase();

        uint256 fromBalance = balanceOf(from);
        require(amount <= fromBalance, "ERC20: transfer amount exceeds balance");

        uint256 sharesAmount;
        if (amount == fromBalance) {
            // Transfer 100% of user's shares to prevent leaving dust due to rounding
            sharesAmount = _shares[from];
        } else {
            sharesAmount = tokenToShares(amount);
        }

        uint256 fromShares = _shares[from];
        require(fromShares >= sharesAmount, "ERC20: transfer amount exceeds shares");

        _shares[from] = fromShares - sharesAmount;
        _shares[to] += sharesAmount;

        emit Transfer(from, to, amount);
    }

    /**
     * @dev Internal approve function.
     */
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Spend allowance.
     */
    function _spendAllowance(address owner, address spender, uint256 amount) internal {
        uint256 currentAllowance = _allowances[owner][spender];
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }
}
