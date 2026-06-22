// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../uniswapv2/interfaces/IUniswapV2Pair.sol";
import "../uniswapv2/libraries/UQ112x112.sol";

contract PoolTWAP {
    using UQ112x112 for uint224;

    address public immutable pair;
    address public immutable token0;
    address public immutable token1;

    uint32 public blockTimestampLast;
    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;

    uint224 public price0Average;
    uint224 public price1Average;

    event TWAPUpdated(uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp, uint224 price0Avg, uint224 price1Avg);

    constructor(address _pair) {
        pair = _pair;
        token0 = IUniswapV2Pair(_pair).token0();
        token1 = IUniswapV2Pair(_pair).token1();
        
        price0CumulativeLast = IUniswapV2Pair(_pair).price0CumulativeLast();
        price1CumulativeLast = IUniswapV2Pair(_pair).price1CumulativeLast();
        
        (, , blockTimestampLast) = IUniswapV2Pair(_pair).getReserves();
    }

    /// @notice Returns current cumulative prices counterfactually (incorporating current block's elapsed time if not synced yet)
    function currentCumulativePrices() public view returns (
        uint256 price0Cumulative,
        uint256 price1Cumulative,
        uint32 blockTimestamp
    ) {
        blockTimestamp = uint32(block.timestamp % 2 ** 32);
        price0Cumulative = IUniswapV2Pair(pair).price0CumulativeLast();
        price1Cumulative = IUniswapV2Pair(pair).price1CumulativeLast();

        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLastPair) = IUniswapV2Pair(pair).getReserves();
        if (blockTimestampLastPair != blockTimestamp) {
            uint32 timeElapsed = blockTimestamp - blockTimestampLastPair;
            unchecked {
                price0Cumulative += uint256(UQ112x112.encode(reserve1).uqdiv(reserve0)) * timeElapsed;
                price1Cumulative += uint256(UQ112x112.encode(reserve0).uqdiv(reserve1)) * timeElapsed;
            }
        }
    }

    /// @notice Computes the new average prices and stores them
    function update() external {
        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) = currentCumulativePrices();
        
        uint32 timeElapsed;
        unchecked {
            timeElapsed = blockTimestamp - blockTimestampLast;
        }
        
        // Ensure at least some time has elapsed before calculating average
        require(timeElapsed > 0, "PoolTWAP: PERIOD_NOT_ELAPSED");

        unchecked {
            // division of cumulative price difference by elapsed time yields the UQ112x112 time-weighted average price
            price0Average = uint224((price0Cumulative - price0CumulativeLast) / timeElapsed);
            price1Average = uint224((price1Cumulative - price1CumulativeLast) / timeElapsed);
        }

        price0CumulativeLast = price0Cumulative;
        price1CumulativeLast = price1Cumulative;
        blockTimestampLast = blockTimestamp;

        emit TWAPUpdated(price0Cumulative, price1Cumulative, blockTimestamp, price0Average, price1Average);
    }

    /// @notice Returns the amount of output tokens equivalent to amountIn of input token based on the TWAP
    function consult(address token, uint256 amountIn) external view returns (uint256 amountOut) {
        if (token == token0) {
            // price0Average is reserve1/reserve0 * 2**112. So amountOut = amountIn * price0Average / 2**112
            amountOut = (amountIn * price0Average) >> 112;
        } else {
            require(token == token1, "PoolTWAP: INVALID_TOKEN");
            // price1Average is reserve0/reserve1 * 2**112. So amountOut = amountIn * price1Average / 2**112
            amountOut = (amountIn * price1Average) >> 112;
        }
    }
}
