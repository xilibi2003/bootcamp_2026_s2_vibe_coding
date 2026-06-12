// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/MyToken1.sol";
import "../src/MyToken2.sol";
import "../src/FlashArbitrage.sol";
import "../uniswapv2/UniswapV2Factory.sol";
import "../uniswapv2/UniswapV2Router02.sol";

contract FlashArbitrageTest is Test {
    MyToken1 public token1;
    MyToken2 public token2;

    UniswapV2Factory public factoryA;
    UniswapV2Factory public factoryB;

    UniswapV2Router02 public routerA;
    UniswapV2Router02 public routerB;

    FlashArbitrage public arbitrage;

    function setUp() public {
        // Deploy tokens
        token1 = new MyToken1();
        token2 = new MyToken2();

        // Deploy factories
        factoryA = new UniswapV2Factory(address(this));
        factoryB = new UniswapV2Factory(address(this));

        // Deploy routers (using dummy WETH address 0x1 since we only trade ERC20 tokens)
        routerA = new UniswapV2Router02(address(factoryA), address(0x1));
        routerB = new UniswapV2Router02(address(factoryB), address(0x1));

        // Create pairs
        factoryA.createPair(address(token1), address(token2));
        factoryB.createPair(address(token1), address(token2));

        // Approvals
        token1.approve(address(routerA), type(uint256).max);
        token2.approve(address(routerA), type(uint256).max);
        token1.approve(address(routerB), type(uint256).max);
        token2.approve(address(routerB), type(uint256).max);

        // Add liquidity to Pool A (1 MTK1 = 2 MTK2)
        // We add 1000 MTK1 and 2000 MTK2
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

        // Add liquidity to Pool B (1 MTK1 = 1 MTK2)
        // We add 1000 MTK1 and 1000 MTK2
        routerB.addLiquidity(
            address(token1),
            address(token2),
            1000 ether,
            1000 ether,
            0,
            0,
            address(this),
            block.timestamp + 1000
        );

        // Deploy Arbitrage contract
        arbitrage = new FlashArbitrage(
            address(token1),
            address(token2),
            address(factoryA),
            address(factoryB)
        );
    }

    function testFlashArbitrage() public {
        // Record balance of token1 before arbitrage
        uint256 initialArbitrageBalance = token1.balanceOf(address(arbitrage));
        assertEq(initialArbitrageBalance, 0);

        // Let's borrow 10 MTK2 from Pool A
        uint256 borrowAmount = 10 ether;



        // Start arbitrage
        arbitrage.startArbitrage(borrowAmount);

        // Check profit
        uint256 finalArbitrageBalance = token1.balanceOf(address(arbitrage));
        console.log("Arbitrage executed successfully!");
        console.log("Borrowed MTK2: %s", borrowAmount / 1e18);
        console.log("Profit in MTK1: %s (%s wei)", finalArbitrageBalance / 1e18, finalArbitrageBalance);

        // The profit should be strictly greater than 0
        assertTrue(finalArbitrageBalance > 0);
    }
}
