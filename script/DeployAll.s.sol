// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseScript} from "./BaseScript.s.sol";
import {MyToken1} from "../src/MyToken1.sol";
import {MyToken2} from "../src/MyToken2.sol";
import {FlashArbitrage} from "../src/FlashArbitrage.sol";
import {UniswapV2Factory} from "../uniswapv2/UniswapV2Factory.sol";
import {UniswapV2Router02} from "../uniswapv2/UniswapV2Router02.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "forge-std/console.sol";

// Minimal WETH implementation for router deployment
contract MockWETH is ERC20 {
    constructor() ERC20("Wrapped Ether", "WETH") {}
    
    function deposit() public payable {
        _mint(msg.sender, msg.value);
    }
    
    function withdraw(uint256 wad) public {
        _burn(msg.sender, wad);
        payable(msg.sender).transfer(wad);
    }
    
    receive() external payable {
        deposit();
    }
}

contract DeployAllScript is BaseScript {
    function setUp() public override {
        super.setUp();
    }

    function run() external broadcaster {
        console.log("Starting deployment on chain ID:", block.chainid);
        console.log("Deployer address:", deployer);

        // 1. Deploy Tokens
        MyToken1 token1 = new MyToken1();
        console.log("MyToken1 deployed at:", address(token1));
        saveContract("MyToken1", address(token1));

        MyToken2 token2 = new MyToken2();
        console.log("MyToken2 deployed at:", address(token2));
        saveContract("MyToken2", address(token2));

        // 2. Deploy Mock WETH
        MockWETH weth = new MockWETH();
        console.log("MockWETH deployed at:", address(weth));
        saveContract("MockWETH", address(weth));

        // 3. Deploy Uniswap V2 Factories
        UniswapV2Factory factoryA = new UniswapV2Factory(deployer);
        console.log("UniswapV2Factory A deployed at:", address(factoryA));
        saveContract("UniswapV2FactoryA", address(factoryA));

        UniswapV2Factory factoryB = new UniswapV2Factory(deployer);
        console.log("UniswapV2Factory B deployed at:", address(factoryB));
        saveContract("UniswapV2FactoryB", address(factoryB));

        // 4. Deploy Uniswap V2 Routers
        UniswapV2Router02 routerA = new UniswapV2Router02(address(factoryA), address(weth));
        console.log("UniswapV2Router02 A deployed at:", address(routerA));
        saveContract("UniswapV2RouterA", address(routerA));

        UniswapV2Router02 routerB = new UniswapV2Router02(address(factoryB), address(weth));
        console.log("UniswapV2Router02 B deployed at:", address(routerB));
        saveContract("UniswapV2RouterB", address(routerB));

        // 5. Create pairs
        address pairA = factoryA.createPair(address(token1), address(token2));
        console.log("Pool A (Pair A) created at:", pairA);
        saveContract("PoolA", pairA);

        address pairB = factoryB.createPair(address(token1), address(token2));
        console.log("Pool B (Pair B) created at:", pairB);
        saveContract("PoolB", pairB);

        // 6. Approve routers to spend deployer's tokens
        token1.approve(address(routerA), type(uint256).max);
        token2.approve(address(routerA), type(uint256).max);
        token1.approve(address(routerB), type(uint256).max);
        token2.approve(address(routerB), type(uint256).max);

        // 7. Add liquidity
        // PoolA: 1000 MTK1 and 2000 MTK2 (Ratio 1:2)
        console.log("Adding liquidity to Pool A...");
        routerA.addLiquidity(
            address(token1),
            address(token2),
            1000 ether,
            2000 ether,
            0,
            0,
            deployer,
            block.timestamp + 1000
        );

        // PoolB: 1000 MTK1 and 1000 MTK2 (Ratio 1:1)
        console.log("Adding liquidity to Pool B...");
        routerB.addLiquidity(
            address(token1),
            address(token2),
            1000 ether,
            1000 ether,
            0,
            0,
            deployer,
            block.timestamp + 1000
        );

        // 8. Deploy FlashArbitrage contract
        FlashArbitrage arbitrage = new FlashArbitrage(
            address(token1),
            address(token2),
            address(factoryA),
            address(factoryB)
        );
        console.log("FlashArbitrage contract deployed at:", address(arbitrage));
        saveContract("FlashArbitrage", address(arbitrage));

        // 9. Execute a verification arbitrage swap of 10 MTK2
        console.log("Executing verification arbitrage of 10 MTK2...");
        uint256 balanceBefore = token1.balanceOf(address(arbitrage));
        
        arbitrage.startArbitrage(10 ether);

        uint256 balanceAfter = token1.balanceOf(address(arbitrage));
        console.log("Verification arbitrage completed!");
        console.log("FlashArbitrage contract MTK1 Profit: %s (%s wei)", (balanceAfter - balanceBefore) / 1e18, (balanceAfter - balanceBefore));
    }
}
