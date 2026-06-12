// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/LaunchPad.sol";
import "../src/LaunchToken.sol";
import "../uniswapv2/UniswapV2Router02.sol";
import "../uniswapv2/UniswapV2Factory.sol";
import "../uniswapv2/UniswapV2Pair.sol";
import "../uniswapv2/libraries/UniswapV2Library.sol";

// Re-using MockWETH from our router tests for testing consistency
contract MockWETH {
    string public name = "Wrapped Ether";
    string public symbol = "WETH";
    uint8 public decimals = 18;

    event Approval(address indexed src, address indexed guy, uint wad);
    event Transfer(address indexed src, address indexed dst, uint wad);
    event Deposit(address indexed dst, uint wad);
    event Withdrawal(address indexed src, uint wad);

    mapping (address => uint) public balanceOf;
    mapping (address => mapping (address => uint)) public allowance;

    receive() external payable {
        deposit();
    }

    function deposit() public payable {
        balanceOf[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint wad) public {
        require(balanceOf[msg.sender] >= wad);
        balanceOf[msg.sender] -= wad;
        payable(msg.sender).transfer(wad);
        emit Withdrawal(msg.sender, wad);
    }

    function totalSupply() public view returns (uint) {
        return address(this).balance;
    }

    function approve(address guy, uint wad) public returns (bool) {
        allowance[msg.sender][guy] = wad;
        emit Approval(msg.sender, guy, wad);
        return true;
    }

    function transfer(address dst, uint wad) public returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }

    function transferFrom(address src, address dst, uint wad) public returns (bool) {
        require(balanceOf[src] >= wad);
        if (src != msg.sender && allowance[src][msg.sender] != type(uint256).max) {
            require(allowance[src][msg.sender] >= wad);
            allowance[src][msg.sender] -= wad;
        }
        balanceOf[src] -= wad;
        balanceOf[dst] += wad;
        emit Transfer(src, dst, wad);
        return true;
    }
}

contract LaunchPadTest is Test {
    receive() external payable {}

    UniswapV2Factory public factory;
    MockWETH public weth;
    UniswapV2Router02 public router;
    LaunchPad public launchPad;

    function setUp() public {
        // Deploy Factory
        factory = new UniswapV2Factory(address(this));

        // Deploy WETH
        weth = new MockWETH();

        // Deploy Router
        router = new UniswapV2Router02(address(factory), address(weth));

        // Deploy LaunchPad
        launchPad = new LaunchPad(address(router));
    }

    function testDeployMemeWithoutLiquidity() public {
        address tokenAddress = launchPad.deployMeme(
            "Meme Token",
            "MEME",
            1_000_000 ether,
            0.001 ether // Price: 0.001 ETH per MEME
        );

        assertTrue(tokenAddress != address(0));

        (address addr, uint256 price, uint256 maxSupply, address creator) = launchPad.memes(tokenAddress);
        assertEq(addr, tokenAddress);
        assertEq(price, 0.001 ether);
        assertEq(maxSupply, 1_000_000 ether);
        assertEq(creator, address(this));

        // Ensure no pool has been created yet
        address pair = factory.getPair(tokenAddress, address(weth));
        assertEq(pair, address(0));
    }


    function testMintMemeFirstTimeLiquidity() public {
        address tokenAddress = launchPad.deployMeme(
            "Meme Token",
            "MEME",
            1_000_000 ether,
            0.001 ether
        );

        // Mint 1000 MEME tokens. Required ETH = 1000 * 0.001 = 1 ether.
        // 5% (0.05 ether) goes to liquidity.
        // At 0.001 price, 0.05 ether = 50 MEME tokens added to liquidity.
        uint256 mintAmount = 1000 ether;
        
        launchPad.mintMeme{value: 1 ether}(tokenAddress, mintAmount);

        // Check that caller received the full minted amount
        LaunchToken token = LaunchToken(tokenAddress);
        assertEq(token.balanceOf(address(this)), mintAmount);

        // Ensure liquidity pool has been created and has reserves
        address pairAddress = factory.getPair(tokenAddress, address(weth));
        assertTrue(pairAddress != address(0));

        UniswapV2Pair pair = UniswapV2Pair(pairAddress);
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        assertTrue(reserve0 > 0);
        assertTrue(reserve1 > 0);
    }

    function testMintMemeMultipleTimesLiquidity() public {
        address tokenAddress = launchPad.deployMeme(
            "Meme Token",
            "MEME",
            1_000_000 ether,
            0.001 ether
        );

        // First mint (seeds pool)
        launchPad.mintMeme{value: 2 ether}(tokenAddress, 2000 ether);

        // Second mint
        launchPad.mintMeme{value: 1 ether}(tokenAddress, 1000 ether);

        LaunchToken token = LaunchToken(tokenAddress);
        assertEq(token.balanceOf(address(this)), 3000 ether);

        address pairAddress = factory.getPair(tokenAddress, address(weth));
        UniswapV2Pair pair = UniswapV2Pair(pairAddress);
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        assertTrue(reserve0 > 0);
        assertTrue(reserve1 > 0);
    }

    function testBuyMeme() public {
        address tokenAddress = launchPad.deployMeme(
            "Meme Token",
            "MEME",
            1_000_000 ether,
            0.001 ether
        );

        // Seed liquidity first via mintMeme
        launchPad.mintMeme{value: 10 ether}(tokenAddress, 10000 ether);

        // Swap 1 ETH for MEME via buyMeme from the pool
        uint256 balanceBefore = LaunchToken(tokenAddress).balanceOf(address(this));

        launchPad.buyMeme{value: 1 ether}(tokenAddress, 0);

        uint256 balanceAfter = LaunchToken(tokenAddress).balanceOf(address(this));
        assertTrue(balanceAfter > balanceBefore);
    }
}
