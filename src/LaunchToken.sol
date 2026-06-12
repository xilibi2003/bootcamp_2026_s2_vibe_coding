// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

contract LaunchToken is ERC20, Ownable {
    uint256 public immutable maxSupply;

    constructor(
        string memory name,
        string memory symbol,
        uint256 _maxSupply,
        address _owner
    ) ERC20(name, symbol) Ownable(_owner) {
        maxSupply = _maxSupply;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        require(totalSupply() + amount <= maxSupply, "Exceeds max supply");
        _mint(to, amount);
    }
}
