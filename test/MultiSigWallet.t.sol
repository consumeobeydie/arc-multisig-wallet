// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/MultiSigWallet.sol";

contract MultiSigWalletTest is Test {
    MultiSigWallet wallet;
    address owner1;
    address owner2;
    address owner3;
    address recipient;

    function setUp() public {
        owner1 = address(0x1111);
        owner2 = address(0x2222);
        owner3 = address(0x3333);
        recipient = address(0x4444);

        vm.deal(owner1, 10 ether);
        vm.deal(owner2, 10 ether);
        vm.deal(owner3, 10 ether);

        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;

        wallet = new MultiSigWallet(owners, 2);
        vm.deal(address(wallet), 10 ether);
    }

    function testInitialState() public view {
        assertEq(wallet.required(), 2);
        assertEq(wallet.owners(0), owner1);
        assertEq(wallet.owners(1), owner2);
        assertEq(wallet.owners(2), owner3);
        assertTrue(wallet.isOwner(owner1));
        assertTrue(wallet.isOwner(owner2));
        assertTrue(wallet.isOwner(owner3));
    }

    function testDeposit() public {
        uint256 balanceBefore = address(wallet).balance;
        vm.prank(owner1);
        (bool success,) = address(wallet).call{value: 1 ether}("");
        assertTrue(success);
        assertEq(address(wallet).balance, balanceBefore + 1 ether);
    }

    function testSubmitTransaction() public {
        vm.prank(owner1);
        uint256 txId = wallet.submitTransaction(recipient, 1 ether, "", "Test tx");
        assertEq(txId, 0);
        assertEq(wallet.transactionCount(), 1);
    }

    function testOnlyOwnerCanSubmit() public {
        vm.prank(recipient);
        vm.expectRevert("Not an owner");
        wallet.submitTransaction(recipient, 1 ether, "", "Test tx");
    }

    function testConfirmTransaction() public {
        vm.prank(owner1);
        wallet.submitTransaction(recipient, 0.5 ether, "", "Test tx");
        vm.prank(owner1);
        wallet.confirmTransaction(0);
        (,,,, uint256 confirmations,) = wallet.getTransaction(0);
        assertEq(confirmations, 1);
    }

    function testCannotConfirmTwice() public {
        vm.prank(owner1);
        wallet.submitTransaction(recipient, 0.5 ether, "", "Test tx");
        vm.prank(owner1);
        wallet.confirmTransaction(0);
        vm.prank(owner1);
        vm.expectRevert("Already confirmed");
        wallet.confirmTransaction(0);
    }

    function testAutoExecuteAfterRequiredConfirmations() public {
        vm.prank(owner1);
        wallet.submitTransaction(recipient, 1 ether, "", "Test tx");
        uint256 balanceBefore = recipient.balance;
        vm.prank(owner1);
        wallet.confirmTransaction(0);
        vm.prank(owner2);
        wallet.confirmTransaction(0);
        assertEq(recipient.balance, balanceBefore + 1 ether);
        (,,, bool executed,,) = wallet.getTransaction(0);
        assertTrue(executed);
    }

    function testRevokeConfirmation() public {
        vm.prank(owner1);
        wallet.submitTransaction(recipient, 1 ether, "", "Test tx");
        vm.prank(owner1);
        wallet.confirmTransaction(0);
        vm.prank(owner1);
        wallet.revokeConfirmation(0);
        (,,,, uint256 confirmations,) = wallet.getTransaction(0);
        assertEq(confirmations, 0);
    }

    function testCannotRevokeIfNotConfirmed() public {
        vm.prank(owner1);
        wallet.submitTransaction(recipient, 1 ether, "", "Test tx");
        vm.prank(owner1);
        vm.expectRevert("Not confirmed");
        wallet.revokeConfirmation(0);
    }

    function testGetOwners() public view {
        address[] memory owners = wallet.getOwners();
        assertEq(owners.length, 3);
        assertEq(owners[0], owner1);
    }

    function testInvalidRequired() public {
        address[] memory owners = new address[](2);
        owners[0] = owner1;
        owners[1] = owner2;
        vm.expectRevert("Invalid required");
        new MultiSigWallet(owners, 3);
    }

    function testTransactionSubmittedEvent() public {
        vm.expectEmit(true, true, true, true);
        emit MultiSigWallet.TransactionSubmitted(0, recipient, 1 ether);
        vm.prank(owner1);
        wallet.submitTransaction(recipient, 1 ether, "", "Test tx");
    }

    receive() external payable {}
}
