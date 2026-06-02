// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {MemeFactory} from "../src/MemeFactory.sol";
import {MemeToken} from "../src/MemeToken.sol";

contract MemeFactoryTest is Test {
    MemeFactory public factory;

    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        factory = new MemeFactory();
    }

    function test_DeploymentAndInitialization() public {
        string memory symbol = "MEME";
        uint256 maxSupply = 1000;
        uint256 perMint = 100;

        address tokenAddr = factory.deployInscription(symbol, maxSupply, perMint);
        assertTrue(tokenAddr != address(0), "Deployment failed");
        assertTrue(factory.isDeployed(tokenAddr), "Factory should track deployment");

        MemeToken token = MemeToken(tokenAddr);

        assertEq(token.name(), symbol, "Name mismatch");
        assertEq(token.symbol(), symbol, "Symbol mismatch");
        assertEq(token.maxSupply(), maxSupply, "Max supply mismatch");
        assertEq(token.perMint(), perMint, "Per mint mismatch");
        assertEq(token.factory(), address(factory), "Factory address mismatch");
        assertEq(token.totalSupply(), 0, "Initial supply should be 0");
    }

    function test_DeployRevertsOnInvalidArguments() public {
        // Zero total supply
        vm.expectRevert("Total supply must be greater than 0");
        factory.deployInscription("MEME", 0, 100);

        // Zero per mint
        vm.expectRevert("Per mint must be greater than 0");
        factory.deployInscription("MEME", 1000, 0);

        // Per mint exceeds total supply
        vm.expectRevert("Per mint must not exceed total supply");
        factory.deployInscription("MEME", 100, 101);

        // Empty symbol
        vm.expectRevert("Symbol cannot be empty");
        factory.deployInscription("", 1000, 100);
    }

    function test_MintInscription() public {
        address tokenAddr = factory.deployInscription("DOGE", 1000, 100);
        MemeToken token = MemeToken(tokenAddr);

        // Mint as Alice
        vm.prank(alice);
        factory.mintInscription(tokenAddr);

        assertEq(token.balanceOf(alice), 100, "Alice should receive perMint tokens");
        assertEq(token.totalSupply(), 100, "Total supply should increase");

        // Mint as Bob
        vm.prank(bob);
        factory.mintInscription(tokenAddr);

        assertEq(token.balanceOf(bob), 100, "Bob should receive perMint tokens");
        assertEq(token.totalSupply(), 200, "Total supply should increase");
    }

    function test_MintRevertsWhenExceedingSupply() public {
        address tokenAddr = factory.deployInscription("SHIB", 250, 100);
        MemeToken token = MemeToken(tokenAddr);

        // Mint 1: 100 (Total: 100)
        vm.prank(alice);
        factory.mintInscription(tokenAddr);

        // Mint 2: 100 (Total: 200)
        vm.prank(bob);
        factory.mintInscription(tokenAddr);

        // Mint 3: 100 (Total would be 300, which exceeds 250 max supply)
        vm.prank(alice);
        vm.expectRevert("Exceeds max supply");
        factory.mintInscription(tokenAddr);

        assertEq(token.totalSupply(), 200, "Total supply should remain 200");
    }

    function test_CloneCannotBeInitializedTwice() public {
        address tokenAddr = factory.deployInscription("PEPE", 1000, 100);
        MemeToken token = MemeToken(tokenAddr);

        vm.expectRevert("Already initialized");
        token.initialize("PEPE2", 2000, 200);
    }

    function test_CannotMintDirectlyOnClone() public {
        address tokenAddr = factory.deployInscription("FLOKI", 1000, 100);
        MemeToken token = MemeToken(tokenAddr);

        vm.prank(alice);
        vm.expectRevert("Only factory can mint");
        token.mint(alice);
    }

    function test_MintRevertsOnNonDeployedToken() public {
        address randomAddress = address(0x1234567890123456789012345678901234567890);
        vm.expectRevert("Token not deployed by this factory");
        factory.mintInscription(randomAddress);
    }
}
