// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract Escrow {
    address public arbiter;
    uint256 public escrowCount;

    enum EscrowStatus { Pending, Completed, Refunded, Disputed }

    struct EscrowDeal {
        uint256 id;
        address depositor;
        address beneficiary;
        uint256 amount;
        EscrowStatus status;
        string description;
        uint256 createdAt;
    }

    mapping(uint256 => EscrowDeal) public escrows;

    event EscrowCreated(uint256 indexed id, address indexed depositor, address indexed beneficiary, uint256 amount);
    event EscrowCompleted(uint256 indexed id, address indexed beneficiary, uint256 amount);
    event EscrowRefunded(uint256 indexed id, address indexed depositor, uint256 amount);
    event EscrowDisputed(uint256 indexed id, address indexed raisedBy);
    event DisputeResolved(uint256 indexed id, bool releasedToBeneficiary);

    modifier onlyArbiter() {
        require(msg.sender == arbiter, "Only arbiter");
        _;
    }

    modifier escrowExists(uint256 escrowId) {
        require(escrowId < escrowCount, "Escrow does not exist");
        _;
    }

    constructor() {
        arbiter = msg.sender;
        escrowCount = 0;
    }

    function createEscrow(
        address beneficiary,
        string memory description
    ) public payable returns (uint256) {
        require(msg.value > 0, "Amount must be greater than zero");
        require(beneficiary != address(0), "Invalid beneficiary");
        require(beneficiary != msg.sender, "Depositor cannot be beneficiary");

        uint256 escrowId = escrowCount;
        escrows[escrowId] = EscrowDeal({
            id: escrowId,
            depositor: msg.sender,
            beneficiary: beneficiary,
            amount: msg.value,
            status: EscrowStatus.Pending,
            description: description,
            createdAt: block.timestamp
        });

        escrowCount++;
        emit EscrowCreated(escrowId, msg.sender, beneficiary, msg.value);
        return escrowId;
    }

    function complete(uint256 escrowId) public escrowExists(escrowId) {
        EscrowDeal storage escrow = escrows[escrowId];
        require(escrow.status == EscrowStatus.Pending, "Escrow is not pending");
        require(msg.sender == escrow.depositor, "Only depositor can complete");

        escrow.status = EscrowStatus.Completed;
        uint256 amount = escrow.amount;
        escrow.amount = 0;

        payable(escrow.beneficiary).transfer(amount);
        emit EscrowCompleted(escrowId, escrow.beneficiary, amount);
    }

    function refund(uint256 escrowId) public escrowExists(escrowId) {
        EscrowDeal storage escrow = escrows[escrowId];
        require(escrow.status == EscrowStatus.Pending, "Escrow is not pending");
        require(
            msg.sender == escrow.depositor || msg.sender == arbiter,
            "Not authorized"
        );

        escrow.status = EscrowStatus.Refunded;
        uint256 amount = escrow.amount;
        escrow.amount = 0;

        payable(escrow.depositor).transfer(amount);
        emit EscrowRefunded(escrowId, escrow.depositor, amount);
    }

    function raiseDispute(uint256 escrowId) public escrowExists(escrowId) {
        EscrowDeal storage escrow = escrows[escrowId];
        require(escrow.status == EscrowStatus.Pending, "Escrow is not pending");
        require(
            msg.sender == escrow.depositor || msg.sender == escrow.beneficiary,
            "Not authorized"
        );

        escrow.status = EscrowStatus.Disputed;
        emit EscrowDisputed(escrowId, msg.sender);
    }

    function resolveDispute(uint256 escrowId, bool releaseToBeneficiary)
        public onlyArbiter escrowExists(escrowId)
    {
        EscrowDeal storage escrow = escrows[escrowId];
        require(escrow.status == EscrowStatus.Disputed, "Escrow is not disputed");

        uint256 amount = escrow.amount;
        escrow.amount = 0;

        if (releaseToBeneficiary) {
            escrow.status = EscrowStatus.Completed;
            payable(escrow.beneficiary).transfer(amount);
            emit EscrowCompleted(escrowId, escrow.beneficiary, amount);
        } else {
            escrow.status = EscrowStatus.Refunded;
            payable(escrow.depositor).transfer(amount);
            emit EscrowRefunded(escrowId, escrow.depositor, amount);
        }

        emit DisputeResolved(escrowId, releaseToBeneficiary);
    }

    function getEscrow(uint256 escrowId) public view escrowExists(escrowId)
        returns (uint256, address, address, uint256, EscrowStatus, string memory, uint256)
    {
        EscrowDeal memory escrow = escrows[escrowId];
        return (
            escrow.id,
            escrow.depositor,
            escrow.beneficiary,
            escrow.amount,
            escrow.status,
            escrow.description,
            escrow.createdAt
        );
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
