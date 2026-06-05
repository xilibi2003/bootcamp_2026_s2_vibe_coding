// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IBank {
    function admin() external view returns (address);

    function balances(address account) external view returns (uint256);

    function deposit() external payable;

    function withdraw() external;

    function getTopDepositors() external view returns (address[10] memory);
}

contract Bank is IBank {
    address public override admin;

    mapping(address => uint256) public balances;
    address public constant GUARD = address(1);
    mapping(address => address) public nextDepositors;
    uint256 public listSize;

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
        nextDepositors[GUARD] = GUARD;
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
        returns (address[10] memory)
    {
        address[10] memory top;
        address curr = GUARD;
        for (uint256 i = 0; i < 10; i++) {
            curr = nextDepositors[curr];
            if (curr == GUARD || curr == address(0)) {
                break;
            }
            top[i] = curr;
        }
        return top;
    }

    function _transferAdmin(address newAdmin) internal {
        require(newAdmin != address(0), "Bank: new admin is zero address");

        address previousAdmin = admin;
        admin = newAdmin;

        emit AdminTransferred(previousAdmin, newAdmin);
    }

    function _updateTopDepositors(address depositor) private {
        // If the depositor is already in the list, remove them first
        if (nextDepositors[depositor] != address(0)) {
            _remove(depositor);
        }

        // If the list is full (has 10 elements) and the depositor's balance
        // is less than or equal to the tail's balance, it does not qualify.
        if (listSize == 10) {
            address tail = _getTail();
            if (balances[depositor] <= balances[tail]) {
                return;
            }
        }

        // Find correct predecessor position
        address prev = _findPredecessor(balances[depositor]);

        // Insert depositor
        nextDepositors[depositor] = nextDepositors[prev];
        nextDepositors[prev] = depositor;
        listSize++;

        // Prune tail if size exceeds 10
        if (listSize > 10) {
            _pruneTail();
        }
    }

    function _remove(address depositor) private {
        address prev = GUARD;
        while (nextDepositors[prev] != depositor) {
            prev = nextDepositors[prev];
        }
        nextDepositors[prev] = nextDepositors[depositor];
        nextDepositors[depositor] = address(0);
        listSize--;
    }

    function _findPredecessor(uint256 balance) private view returns (address) {
        address curr = GUARD;
        while (true) {
            address next = nextDepositors[curr];
            if (next == GUARD || balances[next] < balance) {
                return curr;
            }
            curr = next;
        }
        return GUARD;
    }

    function _getTail() private view returns (address) {
        address curr = GUARD;
        while (nextDepositors[curr] != GUARD) {
            curr = nextDepositors[curr];
        }
        return curr;
    }

    function _pruneTail() private {
        address curr = GUARD;
        for (uint256 i = 0; i < 10; i++) {
            curr = nextDepositors[curr];
        }
        address tail = nextDepositors[curr];
        nextDepositors[curr] = GUARD;
        nextDepositors[tail] = address(0);
        listSize--;
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

