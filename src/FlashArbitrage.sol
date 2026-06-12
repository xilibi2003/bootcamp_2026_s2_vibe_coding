// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../uniswapv2/interfaces/IUniswapV2Pair.sol";
import "../uniswapv2/interfaces/IUniswapV2Callee.sol";
import "../uniswapv2/interfaces/IERC20.sol";
import "../uniswapv2/libraries/UniswapV2Library.sol";

contract FlashArbitrage is IUniswapV2Callee {
    address public immutable token1;
    address public immutable token2;
    address public immutable factoryA;
    address public immutable factoryB;

    event ArbitrageExecuted(uint256 borrowAmount, uint256 amountRepaid, uint256 profit);

    constructor(address _token1, address _token2, address _factoryA, address _factoryB) {
        token1 = _token1;
        token2 = _token2;
        factoryA = _factoryA;
        factoryB = _factoryB;
    }

    /// @notice Triggers the arbitrage by borrowing from PoolA (FactoryA) and trading in PoolB (FactoryB)
    /// @param borrowAmount The amount of token2 to borrow from PoolA
    function startArbitrage(uint256 borrowAmount) external {
        address pairA = UniswapV2Library.pairFor(factoryA, token1, token2);
        require(pairA != address(0), "Invalid pair A");

        (address t0, ) = UniswapV2Library.sortTokens(token1, token2);

        uint256 amount0Out = 0;
        uint256 amount1Out = 0;

        // Borrow token2 (MTK2)
        if (token2 == t0) {
            amount0Out = borrowAmount;
        } else {
            amount1Out = borrowAmount;
        }

        address pairB = UniswapV2Library.pairFor(factoryB, token1, token2);
        bytes memory data = abi.encode(pairB, borrowAmount);

        // Call swap on pairA to trigger flash swap
        IUniswapV2Pair(pairA).swap(amount0Out, amount1Out, address(this), data);
    }

    /// @notice The callback called by UniswapV2Pair during the flash swap
    function uniswapV2Call(
        address sender,
        uint, // amount0 (unused)
        uint, // amount1 (unused)
        bytes calldata data
    ) external override {
        address pairA = msg.sender;

        // Ensure we only accept callbacks from the authentic PairA contract
        require(pairA == UniswapV2Library.pairFor(factoryA, token1, token2), "Unauthorized callback source");
        require(sender == address(this), "Unauthorized initiator");

        // Decode data
        (address pairB, uint256 borrowAmount) = abi.decode(data, (address, uint256));

        // We received borrowAmount of token2.
        // We now swap token2 for token1 in pairB.
        require(IERC20(token2).transfer(pairB, borrowAmount), "Transfer to pairB failed");

        uint256 amountOutB;
        address t0;
        {
            (address sort0, ) = UniswapV2Library.sortTokens(token1, token2);
            t0 = sort0;
            (uint256 reserve0B, uint256 reserve1B, ) = IUniswapV2Pair(pairB).getReserves();

            uint256 reserveInB = (token2 == t0) ? reserve0B : reserve1B;
            uint256 reserveOutB = (token2 == t0) ? reserve1B : reserve0B;

            amountOutB = UniswapV2Library.getAmountOut(borrowAmount, reserveInB, reserveOutB);
        }

        // Perform the swap on pairB
        if (token2 == t0) {
            IUniswapV2Pair(pairB).swap(0, amountOutB, address(this), "");
        } else {
            IUniswapV2Pair(pairB).swap(amountOutB, 0, address(this), "");
        }

        uint256 amountInA;
        {
            (uint256 reserve0A, uint256 reserve1A, ) = IUniswapV2Pair(pairA).getReserves();
            uint256 reserveInA = (token1 == t0) ? reserve0A : reserve1A;
            uint256 reserveOutA = (token1 == t0) ? reserve1A : reserve0A;

            amountInA = UniswapV2Library.getAmountIn(borrowAmount, reserveInA, reserveOutA);
        }

        // Verify profitability
        require(amountOutB > amountInA, "Arbitrage not profitable");

        // Repay pairA
        require(IERC20(token1).transfer(pairA, amountInA), "Repayment to pairA failed");

        emit ArbitrageExecuted(borrowAmount, amountInA, amountOutB - amountInA);
    }
}
