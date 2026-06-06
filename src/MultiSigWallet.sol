// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract MultiSigWallet {
    address[] public owners;
    uint256 public required;
    uint256 public transactionCount;

    struct Transaction {
        uint256 id;
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmations;
        string description;
    }

    mapping(uint256 => Transaction) public transactions;
    mapping(uint256 => mapping(address => bool)) public isConfirmed;
    mapping(address => bool) public isOwner;

    event Deposit(address indexed sender, uint256 amount);
    event TransactionSubmitted(uint256 indexed txId, address indexed to, uint256 value);
    event TransactionConfirmed(uint256 indexed txId, address indexed owner);
    event ConfirmationRevoked(uint256 indexed txId, address indexed owner);
    event TransactionExecuted(uint256 indexed txId);

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }

    modifier txExists(uint256 txId) {
        require(txId < transactionCount, "Transaction does not exist");
        _;
    }

    modifier notExecuted(uint256 txId) {
        require(!transactions[txId].executed, "Already executed");
        _;
    }

    modifier notConfirmed(uint256 txId) {
        require(!isConfirmed[txId][msg.sender], "Already confirmed");
        _;
    }

    constructor(address[] memory _owners, uint256 _required) {
        require(_owners.length > 0, "Owners required");
        require(_required > 0 && _required <= _owners.length, "Invalid required");

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Duplicate owner");
            isOwner[owner] = true;
            owners.push(owner);
        }

        required = _required;
        transactionCount = 0;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function submitTransaction(
        address to,
        uint256 value,
        bytes memory data,
        string memory description
    ) public onlyOwner returns (uint256) {
        require(to != address(0), "Invalid recipient");

        uint256 txId = transactionCount;
        transactions[txId] = Transaction({
            id: txId,
            to: to,
            value: value,
            data: data,
            executed: false,
            confirmations: 0,
            description: description
        });

        transactionCount++;
        emit TransactionSubmitted(txId, to, value);
        return txId;
    }

    function confirmTransaction(uint256 txId)
        public onlyOwner txExists(txId) notExecuted(txId) notConfirmed(txId)
    {
        isConfirmed[txId][msg.sender] = true;
        transactions[txId].confirmations++;
        emit TransactionConfirmed(txId, msg.sender);

        if (transactions[txId].confirmations >= required) {
            executeTransaction(txId);
        }
    }

    function executeTransaction(uint256 txId)
        internal txExists(txId) notExecuted(txId)
    {
        Transaction storage transaction = transactions[txId];
        require(transaction.confirmations >= required, "Insufficient confirmations");
        require(address(this).balance >= transaction.value, "Insufficient balance");

        transaction.executed = true;

        (bool success,) = transaction.to.call{value: transaction.value}(transaction.data);
        require(success, "Transaction failed");

        emit TransactionExecuted(txId);
    }

    function revokeConfirmation(uint256 txId)
        public onlyOwner txExists(txId) notExecuted(txId)
    {
        require(isConfirmed[txId][msg.sender], "Not confirmed");
        isConfirmed[txId][msg.sender] = false;
        transactions[txId].confirmations--;
        emit ConfirmationRevoked(txId, msg.sender);
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getTransaction(uint256 txId) public view txExists(txId)
        returns (uint256, address, uint256, bool, uint256, string memory)
    {
        Transaction memory t = transactions[txId];
        return (t.id, t.to, t.value, t.executed, t.confirmations, t.description);
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
