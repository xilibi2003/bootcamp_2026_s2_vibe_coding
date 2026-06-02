// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Clones} from "openzeppelin-contracts/contracts/proxy/Clones.sol";
import {MemeToken} from "./MemeToken.sol";

contract MemeFactory {
    address public immutable implementation;

    // Track all deployed tokens to prevent arbitrary contract calls in mintInscription
    mapping(address => bool) public isDeployed;

    event InscriptionDeployed(
        address indexed tokenAddress,
        string symbol,
        uint256 totalSupply,
        uint256 perMint
    );

    event InscriptionMinted(
        address indexed tokenAddress,
        address indexed to,
        uint256 amount
    );

    constructor() {
        implementation = address(new MemeToken());
    }

    function deployInscription(
        string calldata symbol,
        uint256 totalSupply,
        uint256 perMint
    ) external returns (address) {
        require(bytes(symbol).length > 0, "Symbol cannot be empty");
        require(totalSupply > 0, "Total supply must be greater than 0");
        require(perMint > 0, "Per mint must be greater than 0");
        require(perMint <= totalSupply, "Per mint must not exceed total supply");

        // Clone the implementation contract using EIP-1167 minimal proxy
        address clone = Clones.clone(implementation);

        // Initialize the cloned contract
        MemeToken(clone).initialize(symbol, totalSupply, perMint);

        // Track the deployed token
        isDeployed[clone] = true;

        emit InscriptionDeployed(clone, symbol, totalSupply, perMint);

        return clone;
    }

    function mintInscription(address tokenAddr) external {
        require(isDeployed[tokenAddr], "Token not deployed by this factory");

        // Call the mint function on the clone
        MemeToken(tokenAddr).mint(msg.sender);

        emit InscriptionMinted(tokenAddr, msg.sender, MemeToken(tokenAddr).perMint());
    }
}
