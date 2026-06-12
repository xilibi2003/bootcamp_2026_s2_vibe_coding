// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {LaunchToken} from "./LaunchToken.sol";
import "../uniswapv2/interfaces/IUniswapV2Router02.sol";
import "../uniswapv2/interfaces/IUniswapV2Factory.sol";
import "../uniswapv2/interfaces/IUniswapV2Pair.sol";
import "../uniswapv2/libraries/UniswapV2Library.sol";

contract LaunchPad {
    address public immutable router;
    address public immutable weth;
    address public immutable factory;

    struct MemeInfo {
        address tokenAddress;
        uint256 price; // ETH per 10^18 units of token (in wei)
        uint256 maxSupply;
        address creator;
    }

    mapping(address => MemeInfo) public memes;
    address[] public allMemes;

    event MemeDeployed(
        address indexed tokenAddress,
        string name,
        string symbol,
        uint256 maxSupply,
        uint256 price,
        address creator
    );

    event MemeMinted(
        address indexed tokenAddress,
        address indexed buyer,
        uint256 amount,
        uint256 ethPaid,
        uint256 liquidityMeme,
        uint256 liquidityETH
    );

    constructor(address _router) {
        router = _router;
        weth = IUniswapV2Router02(_router).WETH();
        factory = IUniswapV2Router02(_router).factory();
    }

    receive() external payable {}

    function deployMeme(
        string calldata name,
        string calldata symbol,
        uint256 maxSupply,
        uint256 price
    ) external returns (address) {
        require(maxSupply > 0, "Max supply must be > 0");
        require(price > 0, "Price must be > 0");

        LaunchToken token = new LaunchToken(name, symbol, maxSupply, address(this));
        address tokenAddress = address(token);

        memes[tokenAddress] = MemeInfo({
            tokenAddress: tokenAddress,
            price: price,
            maxSupply: maxSupply,
            creator: msg.sender
        });
        allMemes.push(tokenAddress);

        emit MemeDeployed(tokenAddress, name, symbol, maxSupply, price, msg.sender);

        return tokenAddress;
    }

    function mintMeme(address tokenAddress, uint256 amount) external payable {
        MemeInfo memory meme = memes[tokenAddress];
        require(meme.tokenAddress != address(0), "Meme does not exist");

        uint256 requiredETH = (amount * meme.price) / 1e18;
        require(msg.value >= requiredETH, "Insufficient ETH sent");

        // Mint the user's purchased Meme tokens
        LaunchToken(tokenAddress).mint(msg.sender, amount);

        // Take 5% for liquidity
        uint256 ethForLiquidity = (requiredETH * 5) / 100;

        // Check if pool already has reserves (is active)
        address pair = IUniswapV2Factory(factory).getPair(tokenAddress, weth);
        bool hasLiquidity = false;
        if (pair != address(0)) {
            (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(pair).getReserves();
            if (reserve0 > 0 && reserve1 > 0) {
                hasLiquidity = true;
            }
        }

        uint256 memeForLiquidity;
        if (!hasLiquidity) {
            memeForLiquidity = (ethForLiquidity * 1e18) / meme.price;
        } else {
            // Sort reserves to get matching token-WETH reserves
            (address token0, ) = UniswapV2Library.sortTokens(tokenAddress, weth);
            (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(pair).getReserves();
            uint256 reserveMeme;
            uint256 reserveETH;
            if (tokenAddress == token0) {
                reserveMeme = uint256(reserve0);
                reserveETH = uint256(reserve1);
            } else {
                reserveMeme = uint256(reserve1);
                reserveETH = uint256(reserve0);
            }

            memeForLiquidity = UniswapV2Library.quote(ethForLiquidity, reserveETH, reserveMeme);
        }

        // Mint matching Meme tokens to the LaunchPad contract for liquidity
        LaunchToken(tokenAddress).mint(address(this), memeForLiquidity);

        // Approve router to spend the contract's Meme tokens
        LaunchToken(tokenAddress).approve(router, memeForLiquidity);

        // Add liquidity to the pool
        IUniswapV2Router02(router).addLiquidityETH{value: ethForLiquidity}(
            tokenAddress,
            memeForLiquidity,
            0,
            0,
            address(this), // LP tokens locked in LaunchPad
            block.timestamp + 1000
        );

        emit MemeMinted(tokenAddress, msg.sender, amount, requiredETH, memeForLiquidity, ethForLiquidity);

        // Refund excess ETH if any
        uint256 refundAmount = msg.value - requiredETH;
        if (refundAmount > 0) {
            payable(msg.sender).transfer(refundAmount);
        }
    }

    function buyMeme(address tokenAddress, uint256 amountOutMin) external payable {
        require(msg.value > 0, "Must send ETH");
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = tokenAddress;

        IUniswapV2Router02(router).swapExactETHForTokens{value: msg.value}(
            amountOutMin,
            path,
            msg.sender,
            block.timestamp + 1000
        );
    }
}
