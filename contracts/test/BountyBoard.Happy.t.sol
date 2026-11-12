// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BountyBoardTestBase} from "./BountyBoard.Base.t.sol";
import {BountyBoard} from "../BountyBoard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract BountyBoardHappyTest is BountyBoardTestBase {
    // ---------------- constructor ----------------

    function test_Constructor_SetsOwnerAndUsdc() public view {
        assertEq(bb.owner(), owner);
        assertEq(address(bb.usdc()), USDC);
        assertEq(bb.USDC_ADDRESS(), USDC);
        assertFalse(bb.emergencyMode());
    }

    function test_Constructor_ZeroOwnerReverts() public {
        // OZ Ownable(0) reverts first with OwnableInvalidOwner
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new BountyBoard(address(0));
    }

    // ---------------- createBounty ----------------

    function test_CreateBounty_StoresAllFieldsAndEscrows() public {
        uint256 dl = START + 1 days;
        vm.expectEmit(false, false, false, true, address(bb));
        emit BountyCreated(0, creator, REWARD, "Fix bug");
        vm.prank(creator);
        bb.createBounty("Fix bug", "Long desc", REWARD, "solidity", dl, "Tests pass", 2, 12);

        BountyBoard.Bounty memory b = bb.getBounty(0);
        assertEq(b.id, 0);
        assertEq(b.creator, creator);
        assertEq(b.title, "Fix bug");
        assertEq(b.description, "Long desc");
        assertEq(b.reward, REWARD);
        assertEq(uint8(b.status), uint8(BountyBoard.BountyStatus.Open));
        assertEq(b.claimer, address(0));
        assertEq(b.tags, "solidity");
        assertEq(b.deadline, dl);
        assertEq(b.acceptanceCriteria, "Tests pass");
        assertEq(b.bountyType, 2);
        assertEq(b.estimatedHours, 12);

        assertEq(_bal(address(bb)), REWARD);
        assertEq(_bal(creator), FUNDS - REWARD);
        assertEq(bb.bountiesCreated(creator), 1);
    }

    function test_CreateBounty_SequentialIdsAndGetBounties() public {
        _create();
        _create();
        assertEq(bb.getBounties().length, 2);
        assertEq(bb.getBounty(1).id, 1);
        assertEq(bb.bountiesCreated(creator), 2);
    }

    function test_CreateBounty_AllowsTypesZeroOneTwoAndNoDeadline() public {
        for (uint8 t = 0; t <= 2; t++) {
            uint256 id = _createWith(1, 0, t);
            assertEq(bb.getBounty(id).bountyType, t);
        }
    }

    function test_CreateBounty_AllowsDeadlineOneSecondAhead() public {
        uint256 id = _createWithDeadline(block.timestamp + 1);
        assertEq(bb.getBounty(id).deadline, START + 1);
    }

    // ---------------- submitWork ----------------

    function test_SubmitWork_Records() public {
        uint256 id = _create();
        vm.expectEmit(false, false, false, true, address(bb));
        emit WorkSubmitted(id, alice, "my work");
        _submit(alice, id);

        BountyBoard.Submission[] memory s = _subs(id);
        assertEq(s.length, 1);
        assertEq(s[0].submitter, alice);
        assertEq(s[0].submissionNote, "my work");
        assertEq(s[0].timestamp, START);
    }

    function test_SubmitWork_AllowedAtExactDeadline() public {
        uint256 id = _createWithDeadline(START + 100);
        vm.warp(START + 100);
        _submit(alice, id);
        assertEq(_subs(id).length, 1);
    }

    function test_SubmitWork_MultipleSubmitters() public {
        uint256 id = _create();
        _submit(alice, id);
        _submit(bob, id);
        assertEq(_subs(id).length, 2);
    }

    function test_SubmitWork_CreatorMaySubmitToOwnBounty() public {
        // documents behaviour (see suspected bugs): no creator != submitter check
        uint256 id = _create();
        _submit(creator, id);
        assertEq(_subs(id).length, 1);
    }

    // ---------------- withdrawSubmission ----------------

    function test_Withdraw_SingleSubmission() public {
        uint256 id = _create();
        _submit(alice, id);
        vm.expectEmit(false, false, false, true, address(bb));
        emit SubmissionWithdrawn(id, alice);
        vm.prank(alice);
        bb.withdrawSubmission(id);
        assertEq(_subs(id).length, 0);
    }

    function test_Withdraw_FirstSwapsLastIntoPlace() public {
        uint256 id = _create();
        _submit(alice, id);
        _submit(bob, id);
        _submit(carol, id);
        vm.prank(alice);
        bb.withdrawSubmission(id);

        BountyBoard.Submission[] memory s = _subs(id);
        assertEq(s.length, 2);
        assertEq(s[0].submitter, carol);
        assertEq(s[1].submitter, bob);
    }

    function test_Withdraw_MiddleSwapsLast() public {
        uint256 id = _create();
        _submit(alice, id);
        _submit(bob, id);
        _submit(carol, id);
        vm.prank(bob);
        bb.withdrawSubmission(id);

        BountyBoard.Submission[] memory s = _subs(id);
        assertEq(s.length, 2);
        assertEq(s[0].submitter, alice);
        assertEq(s[1].submitter, carol);
    }

    function test_Withdraw_LastJustPops() public {
        uint256 id = _create();
        _submit(alice, id);
        _submit(bob, id);
        vm.prank(bob);
        bb.withdrawSubmission(id);

        BountyBoard.Submission[] memory s = _subs(id);
        assertEq(s.length, 1);
        assertEq(s[0].submitter, alice);
    }

    function test_Withdraw_KeepsNotesOfOthersIntact() public {
        uint256 id = _create();
        vm.prank(alice);
        bb.submitWork(id, "A");
        vm.prank(bob);
        bb.submitWork(id, "B");
        vm.prank(carol);
        bb.submitWork(id, "C");
        vm.prank(alice);
        bb.withdrawSubmission(id);

        BountyBoard.Submission[] memory s = _subs(id);
        assertEq(s[0].submissionNote, "C");
        assertEq(s[1].submissionNote, "B");
    }

    function test_Withdraw_AllowsResubmitAfterWithdraw() public {
        uint256 id = _create();
        _submit(alice, id);
        vm.prank(alice);
        bb.withdrawSubmission(id);
        _submit(alice, id);
        assertEq(_subs(id).length, 1);
    }

    function test_Withdraw_AllowedAfterDeadline() public {
        uint256 id = _createWithDeadline(START + 10);
        _submit(alice, id);
        vm.warp(START + 11);
        vm.prank(alice);
        bb.withdrawSubmission(id);
        assertEq(_subs(id).length, 0);
    }

    function test_Withdraw_ThenCancelWorks() public {
        uint256 id = _create();
        _submit(alice, id);
        vm.prank(alice);
        bb.withdrawSubmission(id);
        vm.prank(creator);
        bb.cancelBounty(id);
        assertEq(uint8(_status(id)), uint8(BountyBoard.BountyStatus.Cancelled));
    }

    // ---------------- approveClaimer ----------------

    function test_Approve_PaysClaimerAndUpdatesState() public {
        uint256 id = _create();
        _submit(alice, id);
        vm.expectEmit(false, false, false, true, address(bb));
        emit BountyClaimed(id, alice, REWARD);
        _approve(id, alice);

        assertEq(_bal(alice), FUNDS + REWARD);
        assertEq(_bal(address(bb)), 0);
        BountyBoard.Bounty memory b = bb.getBounty(id);
        assertEq(uint8(b.status), uint8(BountyBoard.BountyStatus.Claimed));
        assertEq(b.claimer, alice);

        (uint256 earned, uint256 won, uint256 created) = bb.getReputation(alice);
        assertEq(earned, REWARD);
        assertEq(won, 1);
        assertEq(created, 0);
    }

    function test_Approve_OnlyPaysChosenAmongMany() public {
        uint256 id = _create();
        _submit(alice, id);
        _submit(bob, id);
        _approve(id, bob);
        assertEq(_bal(bob), FUNDS + REWARD);
        assertEq(_bal(alice), FUNDS);
        assertEq(bb.bountiesWon(alice), 0);
    }

    function test_Approve_AtExactDeadlineStillWorks() public {
        // approveClaimer has no deadline check
        uint256 id = _createWithDeadline(START + 50);
        _submit(alice, id);
        vm.warp(START + 500);
        _approve(id, alice);
        assertEq(_bal(alice), FUNDS + REWARD);
    }

    // ---------------- tipWinner ----------------

    function test_Tip_PaysWinnerFromTipper() public {
        uint256 id = _createClaimed();
        vm.expectEmit(false, false, false, true, address(bb));
        emit WinnerTipped(id, tipper, alice, 25e6);
        vm.prank(tipper);
        bb.tipWinner(id, 25e6);

        assertEq(_bal(alice), FUNDS + REWARD + 25e6);
        assertEq(_bal(tipper), FUNDS - 25e6);
        assertEq(bb.totalEarned(alice), REWARD + 25e6);
        assertEq(bb.bountiesWon(alice), 1);
    }

    function test_Tip_MultipleTipsAccumulate() public {
        uint256 id = _createClaimed();
        vm.prank(tipper);
        bb.tipWinner(id, 10e6);
        vm.prank(bob);
        bb.tipWinner(id, 5e6);
        assertEq(bb.totalEarned(alice), REWARD + 15e6);
        assertEq(_bal(address(bb)), 0);
    }

    // ---------------- cancelBounty ----------------

    function test_Cancel_RefundsCreator() public {
        uint256 id = _create();
        vm.expectEmit(false, false, false, true, address(bb));
        emit BountyCancelled(id);
        vm.prank(creator);
        bb.cancelBounty(id);

        assertEq(uint8(_status(id)), uint8(BountyBoard.BountyStatus.Cancelled));
        assertEq(_bal(creator), FUNDS);
        assertEq(_bal(address(bb)), 0);
    }

    function test_Cancel_BountiesCreatedNotDecremented() public {
        uint256 id = _create();
        vm.prank(creator);
        bb.cancelBounty(id);
        assertEq(bb.bountiesCreated(creator), 1);
    }

    // ---------------- claimExpiredBounty ----------------

    function test_ClaimExpired_OneSecondAfterDeadline() public {
        uint256 id = _createWithDeadline(START + 100);
        vm.warp(START + 101);
        vm.expectEmit(false, false, false, true, address(bb));
        emit BountyCancelled(id);
        vm.prank(creator);
        bb.claimExpiredBounty(id);

        assertEq(uint8(_status(id)), uint8(BountyBoard.BountyStatus.Cancelled));
        assertEq(_bal(creator), FUNDS);
        assertEq(_bal(address(bb)), 0);
    }

    function test_ClaimExpired_WorksEvenWithSubmissions() public {
        uint256 id = _createWithDeadline(START + 100);
        _submit(alice, id);
        vm.warp(START + 101);
        vm.prank(creator);
        bb.claimExpiredBounty(id);
        assertEq(_bal(creator), FUNDS);
    }

    function test_ClaimExpired_WorksInEmergencyMode() public {
        uint256 id = _createWithDeadline(START + 100);
        vm.prank(owner);
        bb.setEmergencyMode(true);
        vm.warp(START + 101);
        vm.prank(creator);
        bb.claimExpiredBounty(id);
        assertEq(_bal(creator), FUNDS);
    }

    // ---------------- emergency ----------------

    function test_SetEmergencyMode_TogglesAndEmits() public {
        vm.expectEmit(false, false, false, true, address(bb));
        emit EmergencyModeUpdated(true);
        vm.prank(owner);
        bb.setEmergencyMode(true);
        assertTrue(bb.emergencyMode());

        vm.expectEmit(false, false, false, true, address(bb));
        emit EmergencyModeUpdated(false);
        vm.prank(owner);
        bb.setEmergencyMode(false);
        assertFalse(bb.emergencyMode());
    }

    function test_EmergencyRefund_RefundsCreator() public {
        uint256 id = _create();
        _submit(alice, id); // submissions do not block emergency refund
        vm.prank(owner);
        bb.setEmergencyMode(true);

        vm.expectEmit(false, false, false, true, address(bb));
        emit BountyCancelled(id);
        vm.prank(owner);
        bb.emergencyRefund(id);

        assertEq(uint8(_status(id)), uint8(BountyBoard.BountyStatus.Cancelled));
        assertEq(_bal(creator), FUNDS);
        assertEq(_bal(address(bb)), 0);
    }

    function test_Emergency_BlocksCreateSubmitWithdrawApproveTipCancel() public {
        uint256 openId = _create();
        _submit(alice, openId);
        uint256 claimedId = _createClaimed();
        vm.prank(owner);
        bb.setEmergencyMode(true);

        vm.startPrank(creator);
        vm.expectRevert("Emergency mode active");
        bb.createBounty("t", "d", 1, "", 0, "", 0, 0);
        vm.expectRevert("Emergency mode active");
        bb.approveClaimer(openId, alice);
        vm.expectRevert("Emergency mode active");
        bb.cancelBounty(openId);
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert("Emergency mode active");
        bb.submitWork(openId, "x");
        vm.expectRevert("Emergency mode active");
        bb.tipWinner(claimedId, 1);
        vm.stopPrank();

        vm.prank(alice);
        vm.expectRevert("Emergency mode active");
        bb.withdrawSubmission(openId);
    }

    // ---------------- views / reputation ----------------

    function test_GetReputation_AggregatesAcrossBounties() public {
        uint256 a = _create();
        uint256 b = _createWith(200e6, 0, 1);
        _submit(alice, a);
        _submit(alice, b);
        _approve(a, alice);
        _approve(b, alice);
        vm.prank(tipper);
        bb.tipWinner(b, 7e6);

        (uint256 earned, uint256 won, uint256 created) = bb.getReputation(alice);
        assertEq(earned, REWARD + 200e6 + 7e6);
        assertEq(won, 2);
        assertEq(created, 0);

        (earned, won, created) = bb.getReputation(creator);
        assertEq(earned, 0);
        assertEq(won, 0);
        assertEq(created, 2);
    }
}
