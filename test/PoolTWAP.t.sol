// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/MyToken1.sol";
import "../src/MyToken2.sol";
import "../src/PoolTWAP.sol";
import "../uniswapv2/UniswapV2Factory.sol";
import "../uniswapv2/UniswapV2Router02.sol";

contract PoolTWAPTest is Test {
    MyToken1 public token1;
    MyToken2 public token2;

    UniswapV2Factory public factoryA;
    UniswapV2Router02 public routerA;
    address public pairA;

    PoolTWAP public twap;

    function setUp() public {
        // Deploy tokens
        token1 = new MyToken1();
        token2 = new MyToken2();

        // Deploy factory
        factoryA = new UniswapV2Factory(address(this));

        // Deploy router
        routerA = new UniswapV2Router02(address(factoryA), address(0x1));

        // Create pair
        pairA = factoryA.createPair(address(token1), address(token2));

        // Approvals
        token1.approve(address(routerA), type(uint256).max);
        token2.approve(address(routerA), type(uint256).max);

        // Add liquidity: 1000 MTK1 and 2000 MTK2 (Ratio 1:2)
        // Initial price: 1 MTK1 = 2 MTK2
        routerA.addLiquidity(
            address(token1),
            address(token2),
            1000 ether,
            2000 ether,
            0,
            0,
            address(this),
            block.timestamp + 1000
        );

        // Start block.timestamp at 1000 to allow clear warp simulations
        vm.warp(1000);

        // Deploy TWAP oracle contract
        twap = new PoolTWAP(pairA);
    }

    // Helper to calculate the current spot price of token1 in terms of token2 (1 token1 = X token2)
    function getSpotPrice() public view returns (uint256) {
        (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(pairA).getReserves();
        address token0 = IUniswapV2Pair(pairA).token0();
        
        if (token0 == address(token1)) {
            // token1 is token0
            return (uint256(reserve1) * 1e18) / uint256(reserve0);
        } else {
            // token1 is token1
            return (uint256(reserve0) * 1e18) / uint256(reserve1);
        }
    }

    function testTWAPPriceSimulation() public {
        console.log("=================== TWAP Simulation ===================");

        // 1. Initial State
        uint256 initialSpot = getSpotPrice();
        console.log("Initial Spot Price (1 MTK1 in MTK2):", initialSpot);
        
        // Warp 10 seconds and call update to set the base price
        vm.warp(block.timestamp + 10);
        twap.update();
        uint256 initialTWAP = twap.consult(address(token1), 1 ether);
        console.log("Initial Consult TWAP Price (1 MTK1 in MTK2):", initialTWAP);
        
        // Assert initial TWAP matches initial spot price
        assertEq(initialTWAP, initialSpot);

        // Warp 15 seconds to simulate time passing at the initial price (2.0)
        vm.warp(block.timestamp + 15);

        // 2. Perform Trade 1: Swap 100 MTK1 for MTK2
        console.log("\n--- Executing Trade 1 (at T=1025): Swap 100 MTK1 for MTK2 ---");
        address[] memory path = new address[](2);
        path[0] = address(token1);
        path[1] = address(token2);
        routerA.swapExactTokensForTokens(
            100 ether,
            0,
            path,
            address(this),
            block.timestamp + 100
        );

        uint256 spotAfterTrade1 = getSpotPrice();
        console.log("Spot Price immediately after Trade 1:", spotAfterTrade1);

        // Warp another 15 seconds to simulate time passing at the new price
        vm.warp(block.timestamp + 15);
        
        // Before calling update, consult should still return initial TWAP
        uint256 twapBeforeUpdate1 = twap.consult(address(token1), 1 ether);
        assertEq(twapBeforeUpdate1, initialTWAP);
        console.log("TWAP Price before update (T=1040):", twapBeforeUpdate1);

        // Update TWAP
        twap.update();
        uint256 twapAfterUpdate1 = twap.consult(address(token1), 1 ether);
        console.log("TWAP Price after update (T=1040):", twapAfterUpdate1);
        
        // Verify that TWAP price is between the initial spot price and the new spot price
        assertTrue(twapAfterUpdate1 < initialSpot); // Because we sold MTK1, its price fell
        assertTrue(twapAfterUpdate1 > spotAfterTrade1); // TWAP lags and is higher than the immediate spot price
        
        // Warp 20 seconds to simulate time passing at the spotAfterTrade1 price
        vm.warp(block.timestamp + 20);

        // 3. Perform Trade 2: Swap 300 MTK2 for MTK1
        console.log("\n--- Executing Trade 2 (at T=1060): Swap 300 MTK2 for MTK1 ---");
        path[0] = address(token2);
        path[1] = address(token1);
        routerA.swapExactTokensForTokens(
            300 ether,
            0,
            path,
            address(this),
            block.timestamp + 100
        );

        uint256 spotAfterTrade2 = getSpotPrice();
        console.log("Spot Price immediately after Trade 2:", spotAfterTrade2);

        // Warp another 40 seconds to simulate time passing at the spotAfterTrade2 price
        vm.warp(block.timestamp + 40);

        // Update TWAP
        twap.update();
        uint256 twapAfterUpdate2 = twap.consult(address(token1), 1 ether);
        console.log("TWAP Price after update (T=1100):", twapAfterUpdate2);

        // Verify that TWAP price correctly adjusted towards the new spot price
        assertTrue(twapAfterUpdate2 > twapAfterUpdate1); // MTK1 bought, price rose
        assertTrue(twapAfterUpdate2 < spotAfterTrade2); // TWAP lags and is lower than the immediate spot price

        console.log("=======================================================");
    }
}
