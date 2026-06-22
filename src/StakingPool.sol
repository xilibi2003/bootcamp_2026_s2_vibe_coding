// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {KKToken} from "./KKToken.sol";

contract StakingPool is ReentrancyGuard {
    struct UserInfo {
        uint256 amount;        // How many ETH the user has staked.
        uint256 rewardDebt;    // Reward debt.
    }

    // The reward token
    KKToken public immutable kkToken;

    // KK Tokens rewarded per block
    uint256 public constant REWARD_PER_BLOCK = 10 * 1e18;

    // Precision factor for reward calculations
    uint256 public constant PRECISION_FACTOR = 1e18;

    // Accumulated KKTokens per share, times PRECISION_FACTOR.
    uint256 public accTokenPerShare;

    // Last block number that KKTokens distribution occurs.
    uint256 public lastRewardBlock;

    // Total staked ETH in this pool
    uint256 public totalStaked;

    // Info of each user that stakes ETH.
    mapping(address => UserInfo) public userInfo;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Claim(address indexed user, uint256 amount);

    constructor() {
        kkToken = new KKToken();
        lastRewardBlock = block.number;
    }

    /**
     * @dev Updates reward variables of the pool to be up-to-date.
     */
    function updatePool() public {
        if (block.number <= lastRewardBlock) {
            return;
        }
        if (totalStaked == 0) {
            lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = block.number - lastRewardBlock;
        uint256 tokenReward = multiplier * REWARD_PER_BLOCK;

        accTokenPerShare += (tokenReward * PRECISION_FACTOR) / totalStaked;
        lastRewardBlock = block.number;
    }

    /**
     * @dev View function to see pending KKTokens on frontend.
     * @param _user Address of the user.
     * @return Pending reward amount in wei.
     */
    function pendingKK(address _user) external view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        uint256 _accTokenPerShare = accTokenPerShare;
        if (block.number > lastRewardBlock && totalStaked != 0) {
            uint256 multiplier = block.number - lastRewardBlock;
            uint256 tokenReward = multiplier * REWARD_PER_BLOCK;
            _accTokenPerShare += (tokenReward * PRECISION_FACTOR) / totalStaked;
        }
        return (user.amount * _accTokenPerShare) / PRECISION_FACTOR - user.rewardDebt;
    }

    /**
     * @dev Deposits ETH to the pool for KKToken reward allocation.
     */
    function deposit() public payable nonReentrant {
        require(msg.value > 0, "StakingPool: Cannot deposit 0");
        updatePool();

        UserInfo storage user = userInfo[msg.sender];
        if (user.amount > 0) {
            uint256 pending = (user.amount * accTokenPerShare) / PRECISION_FACTOR - user.rewardDebt;
            if (pending > 0) {
                kkToken.mint(msg.sender, pending);
                emit Claim(msg.sender, pending);
            }
        }

        user.amount += msg.value;
        totalStaked += msg.value;
        user.rewardDebt = (user.amount * accTokenPerShare) / PRECISION_FACTOR;

        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @dev Withdraws staked ETH from the pool and claims pending rewards.
     * @param amount The amount of ETH to withdraw.
     */
    function withdraw(uint256 amount) external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        require(amount > 0, "StakingPool: Cannot withdraw 0");
        require(user.amount >= amount, "StakingPool: Withdraw amount exceeds balance");

        updatePool();

        uint256 pending = (user.amount * accTokenPerShare) / PRECISION_FACTOR - user.rewardDebt;
        if (pending > 0) {
            kkToken.mint(msg.sender, pending);
            emit Claim(msg.sender, pending);
        }

        user.amount -= amount;
        totalStaked -= amount;
        user.rewardDebt = (user.amount * accTokenPerShare) / PRECISION_FACTOR;

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "StakingPool: ETH transfer failed");

        emit Withdraw(msg.sender, amount);
    }

    /**
     * @dev Claims pending KKToken rewards without changing the staked amount.
     */
    function claim() external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount > 0, "StakingPool: No staked amount");

        updatePool();

        uint256 pending = (user.amount * accTokenPerShare) / PRECISION_FACTOR - user.rewardDebt;
        require(pending > 0, "StakingPool: No reward to claim");

        user.rewardDebt = (user.amount * accTokenPerShare) / PRECISION_FACTOR;
        kkToken.mint(msg.sender, pending);

        emit Claim(msg.sender, pending);
    }

    /**
     * @dev Fallback function to allow direct ETH deposits as staking.
     */
    receive() external payable {
        deposit();
    }
}
