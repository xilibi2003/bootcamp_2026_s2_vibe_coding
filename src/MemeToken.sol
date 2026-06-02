// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MemeToken is ERC20 {
    string private _customName;
    string private _customSymbol;
    uint256 public maxSupply;
    uint256 public perMint;
    address public factory;
    bool private _initialized;

    constructor() ERC20("", "") {}

    function initialize(
        string memory symbol_,
        uint256 maxSupply_,
        uint256 perMint_
    ) external {
        require(!_initialized, "Already initialized");
        _initialized = true;
        _customName = symbol_;
        _customSymbol = symbol_;
        maxSupply = maxSupply_;
        perMint = perMint_;
        factory = msg.sender;
    }

    function name() public view virtual override returns (string memory) {
        return _customName;
    }

    function symbol() public view virtual override returns (string memory) {
        return _customSymbol;
    }

    function mint(address to) external {
        require(msg.sender == factory, "Only factory can mint");
        require(totalSupply() + perMint <= maxSupply, "Exceeds max supply");
        _mint(to, perMint);
    }
}
