// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MyWallet { 
    string public name;
    mapping(address => bool) private approved;
    address public owner;

    modifier auth {
        address _owner;
        assembly {
            _owner := sload(owner.slot)
        }
        require(msg.sender == _owner, "Not authorized");
        _;
    }

    constructor(string memory _name) {
        name = _name;
        address msgSender = msg.sender;
        assembly {
            sstore(owner.slot, msgSender)
        }
    } 

    function transferOwernship(address _addr) public auth {
        require(_addr != address(0), "New owner is the zero address");
        address currentOwner;
        assembly {
            currentOwner := sload(owner.slot)
        }
        require(currentOwner != _addr, "New owner is the same as the old owner");
        assembly {
            sstore(owner.slot, _addr)
        }
    }
}