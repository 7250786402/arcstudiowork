// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BountyBoardTestBase} from "./BountyBoard.Base.t.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// Ownable2Step handover + disabled renounce.
contract BountyBoardOwnershipTest is BountyBoardTestBase {
    address internal newOwner = makeAddr("newOwner");

    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function test_TransferOwnership_OnlyProposes() public {
        vm.expectEmit(true, true, false, false, address(bb));
        emit OwnershipTransferStarted(owner, newOwner);
        vm.prank(owner);
        bb.transferOwnership(newOwner);

        assertEq(bb.owner(), owner);
        assertEq(bb.pendingOwner(), newOwner);
    }

    function test_PendingOwner_HasNoPowersUntilAccepted() public {
        vm.prank(owner);
        bb.transferOwnership(newOwner);

        vm.prank(newOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, newOwner));
        bb.setEmergencyMode(true);

        // old owner keeps power
        vm.prank(owner);
        bb.setEmergencyMode(true);
        assertTrue(bb.emergencyMode());
    }

    function test_AcceptOwnership_CompletesHandover() public {
        vm.prank(owner);
        bb.transferOwnership(newOwner);

        vm.expectEmit(true, true, false, false, address(bb));
        emit OwnershipTransferred(owner, newOwner);
        vm.prank(newOwner);
        bb.acceptOwnership();

        assertEq(bb.owner(), newOwner);
        assertEq(bb.pendingOwner(), address(0));

        vm.prank(newOwner);
        bb.setEmergencyMode(true);
        assertTrue(bb.emergencyMode());

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, owner));
        bb.setEmergencyMode(false);
    }

    function test_AcceptOwnership_NewOwnerCanEmergencyRefund() public {
        uint256 id = _create();
        vm.prank(owner);
        bb.transferOwnership(newOwner);
        vm.prank(newOwner);
        bb.acceptOwnership();
        vm.startPrank(newOwner);
        bb.setEmergencyMode(true);
        bb.emergencyRefund(id);
        vm.stopPrank();
        assertEq(_bal(creator), FUNDS);
    }

    function test_AcceptOwnership_StrangerReverts() public {
        vm.prank(owner);
        bb.transferOwnership(newOwner);
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
        bb.acceptOwnership();
        assertEq(bb.owner(), owner);
        assertEq(bb.pendingOwner(), newOwner);
    }

    function test_AcceptOwnership_WithoutProposalReverts() public {
        vm.prank(newOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, newOwner));
        bb.acceptOwnership();
    }

    function test_AcceptOwnership_OldOwnerCannotAcceptOwnProposal() public {
        vm.prank(owner);
        bb.transferOwnership(newOwner);
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, owner));
        bb.acceptOwnership();
    }

    function test_TransferOwnership_NonOwnerReverts() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
        bb.transferOwnership(newOwner);
    }

    function test_TransferOwnership_ReProposeReplacesPending() public {
        address other = makeAddr("other");
        vm.startPrank(owner);
        bb.transferOwnership(newOwner);
        bb.transferOwnership(other);
        vm.stopPrank();
        assertEq(bb.pendingOwner(), other);

        vm.prank(newOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, newOwner));
        bb.acceptOwnership();

        vm.prank(other);
        bb.acceptOwnership();
        assertEq(bb.owner(), other);
    }

    function test_TransferOwnership_ToZeroOnlyClearsPending() public {
        vm.startPrank(owner);
        bb.transferOwnership(newOwner);
        bb.transferOwnership(address(0)); // Ownable2Step allows zero as pending: cancels the proposal
        vm.stopPrank();
        assertEq(bb.owner(), owner);
        assertEq(bb.pendingOwner(), address(0));
    }

    // ---------------- renounceOwnership disabled ----------------

    function test_Renounce_OwnerReverts() public {
        vm.prank(owner);
        vm.expectRevert("Renounce disabled");
        bb.renounceOwnership();
        assertEq(bb.owner(), owner);
    }

    function test_Renounce_NonOwnerRevertsWithDisabledMessage() public {
        vm.prank(stranger);
        vm.expectRevert("Renounce disabled");
        bb.renounceOwnership();
    }

    function test_Renounce_RevertsEvenInEmergencyMode() public {
        vm.startPrank(owner);
        bb.setEmergencyMode(true);
        vm.expectRevert("Renounce disabled");
        bb.renounceOwnership();
        vm.stopPrank();
        assertEq(bb.owner(), owner);
        assertTrue(bb.emergencyMode());
    }

    function test_Renounce_RevertsForNewOwnerAfterHandover() public {
        vm.prank(owner);
        bb.transferOwnership(newOwner);
        vm.prank(newOwner);
        bb.acceptOwnership();
        vm.prank(newOwner);
        vm.expectRevert("Renounce disabled");
        bb.renounceOwnership();
        assertEq(bb.owner(), newOwner);
    }

    function test_Renounce_RevertsWithPendingOwnerSet() public {
        vm.startPrank(owner);
        bb.transferOwnership(newOwner);
        vm.expectRevert("Renounce disabled");
        bb.renounceOwnership();
        vm.stopPrank();
        assertEq(bb.pendingOwner(), newOwner);
    }
}
