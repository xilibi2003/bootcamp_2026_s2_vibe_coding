// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title MultiSigWallet
 * @dev A simple multi-signature wallet supporting dynamic owners and threshold,
 * permitting owners to submit and confirm proposals, and anyone to execute once confirmed.
 */
contract MultiSigWallet {
    event SubmitTransaction(
        address indexed owner,
        uint256 indexed proposalId,
        address indexed to,
        uint256 value,
        bytes data
    );
    event ConfirmTransaction(address indexed owner, uint256 indexed proposalId);
    event ExecuteTransaction(address indexed executor, uint256 indexed proposalId);

    struct Proposal {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmationsCount;
    }

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public requiredConfirmations;

    Proposal[] public proposals;
    // proposalId => owner => confirmed status
    mapping(uint256 => mapping(address => bool)) public isConfirmed;

    error NotOwner();
    error ProposalDoesNotExist();
    error ProposalAlreadyExecuted();
    error ProposalAlreadyConfirmed();
    error InvalidOwners();
    error InvalidRequiredConfirmations();
    error ConfirmationsThresholdNotMet();
    error ExecutionFailed();

    modifier onlyOwner() {
        if (!isOwner[msg.sender]) revert NotOwner();
        _;
    }

    modifier proposalExists(uint256 proposalId) {
        if (proposalId >= proposals.length) revert ProposalDoesNotExist();
        _;
    }

    modifier notExecuted(uint256 proposalId) {
        if (proposals[proposalId].executed) revert ProposalAlreadyExecuted();
        _;
    }

    modifier notConfirmed(uint256 proposalId) {
        if (isConfirmed[proposalId][msg.sender]) revert ProposalAlreadyConfirmed();
        _;
    }

    constructor(address[] memory _owners, uint256 _requiredConfirmations) {
        if (_owners.length == 0) revert InvalidOwners();
        if (_requiredConfirmations == 0 || _requiredConfirmations > _owners.length) {
            revert InvalidRequiredConfirmations();
        }

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            if (owner == address(0) || isOwner[owner]) revert InvalidOwners();

            isOwner[owner] = true;
            owners.push(owner);
        }

        requiredConfirmations = _requiredConfirmations;
    }

    receive() external payable {}

    /**
     * @dev Proposes a transaction to be executed. The proposer automatically confirms it.
     */
    function propose(
        address destination,
        uint256 value,
        bytes memory data
    ) external onlyOwner returns (uint256 proposalId) {
        proposalId = proposals.length;

        proposals.push(
            Proposal({
                to: destination,
                value: value,
                data: data,
                executed: false,
                confirmationsCount: 1
            })
        );

        isConfirmed[proposalId][msg.sender] = true;

        emit SubmitTransaction(msg.sender, proposalId, destination, value, data);
        emit ConfirmTransaction(msg.sender, proposalId);
    }

    /**
     * @dev Confirms a pending proposal. Can only be called by owners.
     */
    function confirm(
        uint256 proposalId
    )
        external
        onlyOwner
        proposalExists(proposalId)
        notExecuted(proposalId)
        notConfirmed(proposalId)
    {
        isConfirmed[proposalId][msg.sender] = true;
        proposals[proposalId].confirmationsCount += 1;

        emit ConfirmTransaction(msg.sender, proposalId);
    }

    /**
     * @dev Executes a proposal whose confirmations have reached the required threshold.
     * Can be called by anyone.
     */
    function execute(
        uint256 proposalId
    )
        external
        proposalExists(proposalId)
        notExecuted(proposalId)
    {
        Proposal storage proposal = proposals[proposalId];
        if (proposal.confirmationsCount < requiredConfirmations) {
            revert ConfirmationsThresholdNotMet();
        }

        proposal.executed = true;

        (bool success, ) = proposal.to.call{value: proposal.value}(proposal.data);
        if (!success) revert ExecutionFailed();

        emit ExecuteTransaction(msg.sender, proposalId);
    }

    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    function getProposalsCount() external view returns (uint256) {
        return proposals.length;
    }
}
