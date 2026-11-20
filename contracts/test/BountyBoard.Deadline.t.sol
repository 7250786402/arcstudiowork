// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BountyBoardTestBase} from "./BountyBoard.Base.t.sol";
import {BountyBoard} from "../BountyBoard.sol";

/// Mandatory deadline, creator-submit ban, and the REVIEW_GRACE expiry rules.
contract BountyBoardDeadlineTest is BountyBoardTestBase {
    // ---------------- createBounty deadline bounds ----------------

    function test_Create_ZeroDeadlineReverts() public {
        vm.prank(creator);
        vm.expectRevert("Deadline required");
        bb.createBounty("t", "d", 1e6, "", 0, "", 0, 0);
        assertEq(bb.getBounties().length, 0);
        assertEq(bb.bountiesCreated(creator), 0);
    }

    function test_Create_DeadlineNowReverts() public {
        vm.prank(creator);
        vm.expectRevert("Invalid deadline");
        bb.createBounty("t", "d", 1e6, "", block.timestamp, "", 0, 0);
    }

    function test_Create_DeadlineOneSecondPastReverts() public {
        vm.prank(creator);
        vm.expectRevert("Invalid deadline");
        bb.createBounty("t", "d", 1e6, "", block.timestamp - 1, "", 0, 0);
    }

    function test_Create_DeadlineExactly365DaysAllowed() public {
        uint256 id = _createWithDeadline(START + 365 days);
        assertEq(bb.getBounty(id).deadline, START + 365 days);
        assertEq(_bal(address(bb)), REWARD);
    }

    function test_Create_Deadline365DaysPlusOneReverts() public {
        vm.prank(creator);
        vm.expectRevert("Deadline too far");
        bb.createBounty("t", "d", 1e6, "", START + 365 days + 1, "", 0, 0);
        assertEq(bb.getBounties().length, 0);
        assertEq(_bal(address(bb)), 0);
    }

    function test_Create_DeadlineMaxUintReverts() public {
        vm.prank(creator);
        vm.expectRevert("Deadline too far");
        bb.createBounty("t", "d", 1e6, "", type(uint256).max, "", 0, 0);
    }

    function test_Create_TooFarMeasuredFromCurrentTime() public {
        vm.warp(START + 100 days);
        // START + 365 days is only 265 days ahead now: allowed
        uint256 id = _createWithDeadline(START + 365 days);
        assertEq(bb.getBounty(id).deadline, START + 365 days);
        // now + 365 days is allowed, +1 is not
        id = _createWithDeadline(block.timestamp + 365 days);
        assertEq(id, 1);
        vm.prank(creator);
        vm.expectRevert("Deadline too far");
        bb.createBounty("t", "d", 1e6, "", block.timestamp + 365 days + 1, "", 0, 0);
    }

    function test_Create_ValidationOrder_RewardBeforeDeadline() public {
        vm.prank(creator);
        vm.expectRevert("Reward must be > 0");
        bb.createBounty("t", "d", 0, "", 0, "", 0, 0);
    }

    function test_Create_ValidationOrder_DeadlineBeforeType() public {
        vm.prank(creator);
        vm.expectRevert("Deadline required");
        bb.createBounty("t", "d", 1, "", 0, "", 9, 0);
    }

    // ---------------- creator cannot submit ----------------

    function test_Submit_CreatorReverts() public {
        uint256 id = _create();
        vm.prank(creator);
        vm.expectRevert("Creator cannot submit");
        bb.submitWork(id, "mine");
        assertEq(_subs(id).length, 0);
    }

    function test_Submit_CreatorOfOtherBountyCanSubmitHere() public {
        uint256 id = _create();
        // alice creates her own bounty; she can still submit to the creator's one
        vm.prank(alice);
        bb.createBounty("a", "d", 1e6, "", DL, "", 0, 0);
        _submit(alice, id);
        assertEq(_subs(id).length, 1);
        vm.prank(alice);
        vm.expectRevert("Creator cannot submit");
        bb.submitWork(1, "own");
    }

    function test_Submit_CreatorCheckAfterOpenCheck() public {
        uint256 id = _create();
        vm.prank(creator);
        bb.cancelBounty(id);
        vm.prank(creator);
        vm.expectRevert("Bounty not open");
        bb.submitWork(id, "x");
    }

    function test_Submit_CreatorCheckBeforeDeadlineCheck() public {
        uint256 id = _createWithDeadline(START + 10);
        vm.warp(START + 11);
        vm.prank(creator);
        vm.expectRevert("Creator cannot submit");
        bb.submitWork(id, "x");
    }

    function test_Approve_CreatorSelfApprovalImpossible() public {
        uint256 id = _create();
        vm.prank(creator);
        vm.expectRevert("Claimer has no submission");
        bb.approveClaimer(id, creator);
    }

    // ---------------- claimExpiredBounty: no submissions ----------------

    function test_ClaimExpired_NoSubs_RevertsAtExactDeadline() public {
        uint256 id = _createWithDeadline(START + 100);
        vm.warp(START + 100);
        vm.prank(creator);
        vm.expectRevert("Bounty not expired");
        bb.claimExpiredBounty(id);
    }

    function test_ClaimExpired_NoSubs_WorksOneSecondAfterDeadline() public {
        uint256 id = _createWithDeadline(START + 100);
        vm.warp(START + 101);
        vm.prank(creator);
        bb.claimExpiredBounty(id);
        assertEq(uint8(_status(id)), uint8(BountyBoard.BountyStatus.Cancelled));
        assertEq(_bal(creator), FUNDS);
        assertEq(_bal(address(bb)), 0);
    }

    function test_ClaimExpired_NoSubs_SubmissionWithdrawnRestoresFastPath() public {
        uint256 id = _createWithDeadline(START + 100);
        _submit(alice, id);
        vm.prank(alice);
        bb.withdrawSubmission(id);
        vm.warp(START + 101);
        vm.prank(creator);
        bb.claimExpiredBounty(id); // no grace needed: submissions list is empty again
        assertEq(_bal(creator), FUNDS);
    }

    // ---------------- claimExpiredBounty: with submissions (grace) ----------------

    function test_ClaimExpired_WithSubs_RevertsOneSecondAfterDeadline() public {
        uint256 id = _createWithDeadline(START + 100);
        _submit(alice, id);
        vm.warp(START + 101);
        vm.prank(creator);
        vm.expectRevert("Review period not over");
        bb.claimExpiredBounty(id);
        assertEq(uint8(_status(id)), uint8(BountyBoard.BountyStatus.Open));
        assertEq(_bal(address(bb)), REWARD);
    }

    function test_ClaimExpired_WithSubs_RevertsAtExactGraceEnd() public {
        uint256 id = _createWithDeadline(START + 100);
        _submit(alice, id);
        vm.warp(START + 100 + 7 days);
        vm.prank(creator);
        vm.expectRevert("Review period not over");
        bb.claimExpiredBounty(id);
    }

    function test_ClaimExpired_WithSubs_RevertsOneSecondBeforeGraceEnd() public {
        uint256 id = _createWithDeadline(START + 100);
        _submit(alice, id);
        vm.warp(START + 100 + 7 days - 1);
        vm.prank(creator);
        vm.expectRevert("Review period not over");
        bb.claimExpiredBounty(id);
    }

    function test_ClaimExpired_WithSubs_WorksOneSecondAfterGraceEnd() public {
        uint256 id = _createWithDeadline(START + 100);
        _submit(alice, id);
        vm.warp(START + 100 + 7 days + 1);
        vm.expectEmit(false, false, false, true, address(bb));
        emit BountyCancelled(id);
        vm.prank(creator);
        bb.claimExpiredBounty(id);
        assertEq(uint8(_status(id)), uint8(BountyBoard.BountyStatus.Cancelled));
        assertEq(_bal(creator), FUNDS);
        assertEq(_bal(address(bb)), 0);
    }

    function test_ClaimExpired_BeforeDeadlineStillNotExpiredWithSubs() public {
        uint256 id = _createWithDeadline(START + 100);
        _submit(alice, id);
        vm.warp(START + 100);
        vm.prank(creator);
        vm.expectRevert("Bounty not expired");
        bb.claimExpiredBounty(id);
    }

    function test_ClaimExpired_ReviewGraceIsSevenDays() public view {
        assertEq(bb.REVIEW_GRACE(), 7 days);
    }

    function test_ClaimExpired_NonCreatorStillRevertsInsideAndAfterGrace() public {
        uint256 id = _createWithDeadline(START + 100);
        _submit(alice, id);
        vm.warp(START + 100 + 7 days + 1);
        vm.prank(stranger);
        vm.expectRevert("Not bounty creator");
        bb.claimExpiredBounty(id);
        vm.prank(alice);
        vm.expectRevert("Not bounty creator");
        bb.claimExpiredBounty(id);
    }

    // ---------------- approveClaimer inside the grace window ----------------

    function test_Approve_WorksAfterDeadlineBeforeGraceEnds() public {
        uint256 id = _createWithDeadline(START + 100);
        _submit(alice, id);
        vm.warp(START + 100 + 7 days); // exact grace end: creator cannot reclaim yet, can still approve
        vm.prank(creator);
        vm.expectRevert("Review period not over");
        bb.claimExpiredBounty(id);

        _approve(id, alice);
        assertEq(_bal(alice), FUNDS + REWARD);
        assertEq(uint8(_status(id)), uint8(BountyBoard.BountyStatus.Claimed));
    }

    function test_Approve_WorksJustAfterDeadline() public {
        uint256 id = _createWithDeadline(START + 100);
        _submit(alice, id);
        vm.warp(START + 101);
        _approve(id, alice);
        assertEq(bb.getBounty(id).claimer, alice);
    }

    function test_Approve_StillWorksAfterGraceUntilCreatorReclaims() public {
        uint256 id = _createWithDeadline(START + 100);
        _submit(alice, id);
        vm.warp(START + 100 + 7 days + 1);
        _approve(id, alice); // not yet reclaimed, so still allowed
        assertEq(_bal(alice), FUNDS + REWARD);
        // and the reclaim path is now closed
        vm.prank(creator);
        vm.expectRevert("Bounty not open");
        bb.claimExpiredBounty(id);
    }

    function test_Approve_FailsAfterCreatorReclaims() public {
        uint256 id = _createWithDeadline(START + 100);
        _submit(alice, id);
        vm.warp(START + 100 + 7 days + 1);
        vm.prank(creator);
        bb.claimExpiredBounty(id);
        vm.prank(creator);
        vm.expectRevert("Bounty not open");
        bb.approveClaimer(id, alice);
    }

    function test_Submit_RejectedAfterDeadlineEvenInsideGrace() public {
        uint256 id = _createWithDeadline(START + 100);
        _submit(alice, id);
        vm.warp(START + 101);
        vm.prank(bob);
        vm.expectRevert("Bounty deadline passed");
        bb.submitWork(id, "late");
    }

    function test_Withdraw_InsideGraceReopensFastReclaim() public {
        uint256 id = _createWithDeadline(START + 100);
        _submit(alice, id);
        vm.warp(START + 101);
        vm.prank(creator);
        vm.expectRevert("Review period not over");
        bb.claimExpiredBounty(id);

        vm.prank(alice);
        bb.withdrawSubmission(id);
        vm.prank(creator);
        bb.claimExpiredBounty(id);
        assertEq(_bal(creator), FUNDS);
    }

    // ---------------- fuzz ----------------

    function testFuzz_Create_DeadlineWindow(uint256 deadline) public {
        deadline = bound(deadline, 0, START + 800 days);
        vm.prank(creator);
        if (deadline == 0) {
            vm.expectRevert("Deadline required");
        } else if (deadline <= START) {
            vm.expectRevert("Invalid deadline");
        } else if (deadline > START + 365 days) {
            vm.expectRevert("Deadline too far");
        }
        bb.createBounty("t", "d", 1e6, "", deadline, "", 0, 0);
    }

    function testFuzz_ClaimExpired_WithSubs_Boundaries(uint256 offset, uint256 delta) public {
        offset = bound(offset, 1, 300 days);
        delta = bound(delta, 0, 40 days);
        uint256 dl = START + offset;
        uint256 id = _createWithDeadline(dl);
        _submit(alice, id);
        vm.warp(START + offset + delta);

        vm.prank(creator);
        if (block.timestamp <= dl) {
            vm.expectRevert("Bounty not expired");
        } else if (block.timestamp <= dl + 7 days) {
            vm.expectRevert("Review period not over");
        }
        bb.claimExpiredBounty(id);
    }

    function testFuzz_ClaimExpired_NoSubs_Boundaries(uint256 offset, uint256 delta) public {
        offset = bound(offset, 1, 365 days);
        delta = bound(delta, 0, 400 days);
        uint256 dl = START + offset;
        uint256 id = _createWithDeadline(dl);
        vm.warp(START + delta);

        vm.prank(creator);
        if (block.timestamp <= dl) vm.expectRevert("Bounty not expired");
        bb.claimExpiredBounty(id);
    }
}
