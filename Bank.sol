// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IBank {
    function admin() external view returns (address);

    function balances(address account) external view returns (uint256);

    function deposit() external payable;

    function withdraw() external;

    function getTopDepositors() external view returns (address[3] memory);
}

contract Bank is IBank {
    address public override admin;

    mapping(address => uint256) public balances;
    address[3] public topDepositors;

    event Deposited(
        address indexed depositor,
        uint256 amount,
        uint256 totalAmount
    );
    event Withdrawn(address indexed admin, uint256 amount);
    event AdminTransferred(
        address indexed previousAdmin,
        address indexed newAdmin
    );

    modifier onlyAdmin() {
        require(msg.sender == admin, "Bank: caller is not admin");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    receive() external payable {
        deposit();
    }

    function deposit() public payable virtual override {
        require(msg.value > 0, "Bank: deposit amount is zero");

        balances[msg.sender] += msg.value;
        _updateTopDepositors(msg.sender);

        emit Deposited(msg.sender, msg.value, balances[msg.sender]);
    }

    function withdraw() external virtual override onlyAdmin {
        uint256 amount = address(this).balance;
        require(amount > 0, "Bank: no ETH to withdraw");

        (bool success, ) = payable(admin).call{value: amount}("");
        require(success, "Bank: withdraw failed");

        emit Withdrawn(admin, amount);
    }

    function getTopDepositors()
        external
        view
        override
        returns (address[3] memory)
    {
        return topDepositors;
    }

    function _transferAdmin(address newAdmin) internal {
        require(newAdmin != address(0), "Bank: new admin is zero address");

        address previousAdmin = admin;
        admin = newAdmin;

        emit AdminTransferred(previousAdmin, newAdmin);
    }

    function _updateTopDepositors(address depositor) private {
        for (uint256 i = 0; i < topDepositors.length; i++) {
            if (topDepositors[i] == depositor) {
                _sortTopDepositors();
                return;
            }
        }

        for (uint256 i = 0; i < topDepositors.length; i++) {
            if (
                topDepositors[i] == address(0) ||
                balances[depositor] > balances[topDepositors[i]]
            ) {
                for (uint256 j = topDepositors.length - 1; j > i; j--) {
                    topDepositors[j] = topDepositors[j - 1];
                }
                topDepositors[i] = depositor;
                return;
            }
        }
    }

    function _sortTopDepositors() private {
        for (uint256 i = 0; i < topDepositors.length; i++) {
            for (uint256 j = i + 1; j < topDepositors.length; j++) {
                if (balances[topDepositors[j]] > balances[topDepositors[i]]) {
                    address temp = topDepositors[i];
                    topDepositors[i] = topDepositors[j];
                    topDepositors[j] = temp;
                }
            }
        }
    }
}

contract BigBank is Bank {
    uint256 public constant MIN_DEPOSIT = 0.001 ether;

    modifier onlyLargeDeposit() {
        require(
            msg.value > MIN_DEPOSIT,
            "BigBank: deposit amount must exceed 0.001 ether"
        );
        _;
    }

    function deposit() public payable override onlyLargeDeposit {
        super.deposit();
    }

    function transferAdmin(address newAdmin) external onlyAdmin {
        _transferAdmin(newAdmin);
    }
}
