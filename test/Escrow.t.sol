// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/Escrow.sol";

contract EscrowTest is Test {
    Escrow escrow;
    address arbiter;
    address depositor;
    address beneficiary;
    address user;

    function setUp() public {
        arbiter = address(this);
        depositor = address(0x1234);
        beneficiary = address(0x5678);
        user = address(0x9abc);
        vm.deal(depositor, 10 ether);
        vm.deal(user, 10 ether);
        escrow = new Escrow();
    }

    function testInitialState() public view {
        assertEq(escrow.arbiter(), arbiter);
        assertEq(escrow.escrowCount(), 0);
        assertEq(escrow.getContractBalance(), 0);
    }

    function testCreateEscrow() public {
        vm.prank(depositor);
        uint256 id = escrow.createEscrow{value: 1 ether}(beneficiary, "Test Deal");
        assertEq(id, 0);
        assertEq(escrow.escrowCount(), 1);
        assertEq(escrow.getContractBalance(), 1 ether);
    }

    function testCannotCreateWithZeroAmount() public {
        vm.prank(depositor);
        vm.expectRevert("Amount must be greater than zero");
        escrow.createEscrow{value: 0}(beneficiary, "Test Deal");
    }

    function testCannotCreateWithSameDepositorAndBeneficiary() public {
        vm.prank(depositor);
        vm.expectRevert("Depositor cannot be beneficiary");
        escrow.createEscrow{value: 1 ether}(depositor, "Test Deal");
    }

    function testComplete() public {
        vm.prank(depositor);
        escrow.createEscrow{value: 1 ether}(beneficiary, "Test Deal");
        uint256 balanceBefore = beneficiary.balance;
        vm.prank(depositor);
        escrow.complete(0);
        assertEq(beneficiary.balance, balanceBefore + 1 ether);
    }

    function testOnlyDepositorCanComplete() public {
        vm.prank(depositor);
        escrow.createEscrow{value: 1 ether}(beneficiary, "Test Deal");
        vm.prank(user);
        vm.expectRevert("Only depositor can complete");
        escrow.complete(0);
    }

    function testRefund() public {
        vm.prank(depositor);
        escrow.createEscrow{value: 1 ether}(beneficiary, "Test Deal");
        uint256 balanceBefore = depositor.balance;
        vm.prank(depositor);
        escrow.refund(0);
        assertEq(depositor.balance, balanceBefore + 1 ether);
    }

    function testArbiterCanRefund() public {
        vm.prank(depositor);
        escrow.createEscrow{value: 1 ether}(beneficiary, "Test Deal");
        uint256 balanceBefore = depositor.balance;
        escrow.refund(0);
        assertEq(depositor.balance, balanceBefore + 1 ether);
    }

    function testRaiseDispute() public {
        vm.prank(depositor);
        escrow.createEscrow{value: 1 ether}(beneficiary, "Test Deal");
        vm.prank(depositor);
        escrow.raiseDispute(0);
        (,,,,Escrow.EscrowStatus status,,) = escrow.getEscrow(0);
        assertEq(uint256(status), uint256(Escrow.EscrowStatus.Disputed));
    }

    function testResolveDisputeToBeneficiary() public {
        vm.prank(depositor);
        escrow.createEscrow{value: 1 ether}(beneficiary, "Test Deal");
        vm.prank(depositor);
        escrow.raiseDispute(0);
        uint256 balanceBefore = beneficiary.balance;
        escrow.resolveDispute(0, true);
        assertEq(beneficiary.balance, balanceBefore + 1 ether);
    }

    function testResolveDisputeToDepositor() public {
        vm.prank(depositor);
        escrow.createEscrow{value: 1 ether}(beneficiary, "Test Deal");
        vm.prank(depositor);
        escrow.raiseDispute(0);
        uint256 balanceBefore = depositor.balance;
        escrow.resolveDispute(0, false);
        assertEq(depositor.balance, balanceBefore + 1 ether);
    }

    function testOnlyArbiterCanResolveDispute() public {
        vm.prank(depositor);
        escrow.createEscrow{value: 1 ether}(beneficiary, "Test Deal");
        vm.prank(depositor);
        escrow.raiseDispute(0);
        vm.prank(user);
        vm.expectRevert("Only arbiter");
        escrow.resolveDispute(0, true);
    }

    function testEscrowCreatedEvent() public {
        vm.expectEmit(true, true, true, true);
        emit Escrow.EscrowCreated(0, depositor, beneficiary, 1 ether);
        vm.prank(depositor);
        escrow.createEscrow{value: 1 ether}(beneficiary, "Test Deal");
    }

    receive() external payable {}
}
