// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BountyBoardTestBase} from "./BountyBoard.Base.t.sol";
import {BountyBoard} from "../BountyBoard.sol";
import {MockERC20} from "../test-helpers/MockERC20.sol";
import {MockBlockableERC20} from "../test-helpers/MockBlockableERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract BountyBoardRevertTest is BountyBoardTestBase {
    uint256 internal constant UNKNOWN = 999;

    // ---------------- createBounty ----------------

    function test_Create_ZeroRewardReverts() public {
        vm.prank(creator);
        vm.expectRevert("Reward must be > 0");
        bb.createBounty("t", "d", 0, "", 0, "", 0, 0);
    }

    function test_Create_DeadlineEqualNowReverts() public {
        vm.prank(creator);
        vm.expectRevert("Invalid deadline");
        bb.createBounty("t", "d", 1, "", START, "", 0, 0);
    }

    function test_Create_DeadlineInPastReverts() public {
        vm.prank(creator);
        vm.expectRevert("Invalid deadline");
        bb.createBounty("t", "d", 1, "", START - 1, "", 0, 0);
    }

    function test_Create_BadTypeReverts() public {
        vm.prank(creator);
        vm.expectRevert("Invalid bounty type");
        bb.createBounty("t", "d", 1, "", 0, "", 3, 0);
    }

    function test_Create_NoAllowanceReverts() public {
        address noApproval = makeAddr("noApproval");
        usdc.mint(noApproval, 100e6);
        vm.prank(noApproval);
        vm.expectRevert(bytes("allowance"));
        bb.createBounty("t", "d", 1e6, "", 0, "", 0, 0);
    }

    function test_Create_InsufficientBalanceReverts() public {
        address poor = makeAddr("poor");
        vm.startPrank(poor);
        usdc.approve(address(bb), type(uint256).max);
        vm.expectRevert(bytes("balance"));
        bb.createBounty("t", "d", 1e6, "", 0, "", 0, 0);
        vm.stopPrank();
    }

    // ---------------- submitWork ----------------

    function test_Submit_UnknownIdReverts() public {
        vm.prank(alice);
        vm.expectRevert("Invalid bounty id");
        bb.submitWork(UNKNOWN, "x");
    }

    function test_Submit_DuplicateReverts() public {
        uint256 id = _create();
        _submit(alice, id);
        vm.prank(alice);
        vm.expectRevert("Already submitted");
        bb.submitWork(id, "again");
    }

    function test_Submit_PastDeadlineReverts() public {
        uint256 id = _createWithDeadline(START + 100);
        vm.warp(START + 101);
        vm.prank(alice);
        vm.expectRevert("Bounty deadline passed");
        bb.submitWork(id, "late");
    }

    function test_Submit_ClaimedReverts() public {
        uint256 id = _createClaimed();
        vm.prank(bob);
        vm.expectRevert("Bounty not open");
        bb.submitWork(id, "x");
    }

    function test_Submit_CancelledReverts() public {
        uint256 id = _create();
        vm.prank(creator);
        bb.cancelBounty(id);
        vm.prank(bob);
        vm.expectRevert("Bounty not open");
        bb.submitWork(id, "x");
    }

    // ---------------- withdrawSubmission ----------------

    function test_Withdraw_UnknownIdReverts() public {
        vm.prank(alice);
        vm.expectRevert("Invalid bounty id");
        bb.withdrawSubmission(UNKNOWN);
    }

    function test_Withdraw_NoSubmissionReverts() public {
        uint256 id = _create();
        vm.prank(alice);
        vm.expectRevert("No submission found");
        bb.withdrawSubmission(id);
    }

    function test_Withdraw_TwiceReverts() public {
        uint256 id = _create();
        _submit(alice, id);
        vm.startPrank(alice);
        bb.withdrawSubmission(id);
        vm.expectRevert("No submission found");
        bb.withdrawSubmission(id);
        vm.stopPrank();
    }

    function test_Withdraw_NotOpenReverts() public {
        uint256 id = _create();
        _submit(alice, id);
        _submit(bob, id);
        _approve(id, alice);
        vm.prank(bob);
        vm.expectRevert("Bounty not open");
        bb.withdrawSubmission(id);
    }

    // ---------------- approveClaimer ----------------

    function test_Approve_UnknownIdReverts() public {
        vm.prank(creator);
        vm.expectRevert("Invalid bounty id");
        bb.approveClaimer(UNKNOWN, alice);
    }

    function test_Approve_NonCreatorReverts() public {
        uint256 id = _create();
        _submit(alice, id);
        vm.prank(stranger);
        vm.expectRevert("Not bounty creator");
        bb.approveClaimer(id, alice);
    }

    function test_Approve_AlreadyClaimedReverts() public {
        uint256 id = _createClaimed();
        vm.prank(creator);
        vm.expectRevert("Bounty not open");
        bb.approveClaimer(id, alice);
    }

    function test_Approve_CancelledReverts() public {
        uint256 id = _create();
        vm.prank(creator);
        bb.cancelBounty(id);
        vm.prank(creator);
        vm.expectRevert("Bounty not open");
        bb.approveClaimer(id, alice);
    }

    function test_Approve_ZeroClaimerReverts() public {
        uint256 id = _create();
        vm.prank(creator);
        vm.expectRevert("Claimer is zero");
        bb.approveClaimer(id, address(0));
    }

    function test_Approve_ClaimerWithoutSubmissionReverts() public {
        uint256 id = _create();
        _submit(alice, id);
        vm.prank(creator);
        vm.expectRevert("Claimer has no submission");
        bb.approveClaimer(id, bob);
    }

    function test_Approve_WithdrawnClaimerReverts() public {
        uint256 id = _create();
        _submit(alice, id);
        vm.prank(alice);
        bb.withdrawSubmission(id);
        vm.prank(creator);
        vm.expectRevert("Claimer has no submission");
        bb.approveClaimer(id, alice);
    }

    function _blockableEtch() internal returns (MockBlockableERC20 t) {
        // keep storage (balances) from the seeded MockERC20, swap in blockable code
        MockBlockableERC20 impl = new MockBlockableERC20();
        vm.etch(USDC, address(impl).code);
        t = MockBlockableERC20(USDC);
    }

    function test_Approve_TransferRevertsBubblesContractMessageAndStaysOpen() public {
        uint256 id = _create();
        _submit(alice, id);
        MockBlockableERC20 t = _blockableEtch();
        t.setBlock(alice, 1);

        vm.prank(creator);
        vm.expectRevert("Winner address cannot receive USDC");
        bb.approveClaimer(id, alice);

        BountyBoard.Bounty memory b = bb.getBounty(id);
        assertEq(uint8(b.status), uint8(BountyBoard.BountyStatus.Open));
        assertEq(b.claimer, address(0));
        assertEq(_bal(address(bb)), REWARD);
        assertEq(bb.totalEarned(alice), 0);
        assertEq(bb.bountiesWon(alice), 0);
    }

    function test_Approve_TransferReturnsFalseRevertsAndStaysOpen() public {
        uint256 id = _create();
        _submit(alice, id);
        MockBlockableERC20 t = _blockableEtch();
        t.setBlock(alice, 2);

        vm.prank(creator);
        vm.expectRevert("Winner address cannot receive USDC");
        bb.approveClaimer(id, alice);

        assertEq(uint8(_status(id)), uint8(BountyBoard.BountyStatus.Open));
        assertEq(_bal(address(bb)), REWARD);
    }

    function test_Approve_AfterBlockedClaimerCanPickAnother() public {
        uint256 id = _create();
        _submit(alice, id);
        _submit(bob, id);
        MockBlockableERC20 t = _blockableEtch();
        t.setBlock(alice, 1);

        vm.prank(creator);
        vm.expectRevert("Winner address cannot receive USDC");
        bb.approveClaimer(id, alice);

        _approve(id, bob);
        assertEq(bb.getBounty(id).claimer, bob);
        assertEq(_bal(bob), FUNDS + REWARD);
    }

    // ---------------- tipWinner ----------------

    function test_Tip_UnknownIdReverts() public {
        vm.prank(tipper);
        vm.expectRevert("Invalid bounty id");
        bb.tipWinner(UNKNOWN, 1);
    }

    function test_Tip_ZeroAmountReverts() public {
        uint256 id = _createClaimed();
        vm.prank(tipper);
        vm.expectRevert("Amount must be > 0");
        bb.tipWinner(id, 0);
    }

    function test_Tip_OpenBountyReverts() public {
        uint256 id = _create();
        vm.prank(tipper);
        vm.expectRevert("Bounty not claimed");
        bb.tipWinner(id, 1e6);
    }

    function test_Tip_CancelledBountyReverts() public {
        uint256 id = _create();
        vm.prank(creator);
        bb.cancelBounty(id);
        vm.prank(tipper);
        vm.expectRevert("Bounty not claimed");
        bb.tipWinner(id, 1e6);
    }

    function test_Tip_InsufficientAllowanceReverts() public {
        uint256 id = _createClaimed();
        address noApproval = makeAddr("noApproval");
        usdc.mint(noApproval, 10e6);
        vm.prank(noApproval);
        vm.expectRevert(bytes("allowance"));
        bb.tipWinner(id, 1e6);
    }

    // ---------------- cancelBounty ----------------

    function test_Cancel_UnknownIdReverts() public {
        vm.prank(creator);
        vm.expectRevert("Invalid bounty id");
        bb.cancelBounty(UNKNOWN);
    }

    function test_Cancel_NonCreatorReverts() public {
        uint256 id = _create();
        vm.prank(stranger);
        vm.expectRevert("Not bounty creator");
        bb.cancelBounty(id);
    }

    function test_Cancel_WithSubmissionsReverts() public {
        uint256 id = _create();
        _submit(alice, id);
        vm.prank(creator);
        vm.expectRevert("Submissions exist");
        bb.cancelBounty(id);
    }

    function test_Cancel_TwiceReverts() public {
        uint256 id = _create();
        vm.startPrank(creator);
        bb.cancelBounty(id);
        vm.expectRevert("Bounty not open");
        bb.cancelBounty(id);
        vm.stopPrank();
    }

    function test_Cancel_ClaimedReverts() public {
        uint256 id = _createClaimed();
        vm.prank(creator);
        vm.expectRevert("Bounty not open");
        bb.cancelBounty(id);
    }

    // ---------------- claimExpiredBounty ----------------

    function test_ClaimExpired_UnknownIdReverts() public {
        vm.prank(creator);
        vm.expectRevert("Invalid bounty id");
        bb.claimExpiredBounty(UNKNOWN);
    }

    function test_ClaimExpired_AtExactDeadlineReverts() public {
        uint256 id = _createWithDeadline(START + 100);
        vm.warp(START + 100);
        vm.prank(creator);
        vm.expectRevert("Bounty not expired");
        bb.claimExpiredBounty(id);
    }

    function test_ClaimExpired_BeforeDeadlineReverts() public {
        uint256 id = _createWithDeadline(START + 100);
        vm.prank(creator);
        vm.expectRevert("Bounty not expired");
        bb.claimExpiredBounty(id);
    }

    function test_ClaimExpired_NoDeadlineNeverExpires() public {
        uint256 id = _create();
        vm.warp(START + 3650 days);
        vm.prank(creator);
        vm.expectRevert("Bounty not expired");
        bb.claimExpiredBounty(id);
    }

    function test_ClaimExpired_NonCreatorAfterDeadlineReverts() public {
        uint256 id = _createWithDeadline(START + 100);
        vm.warp(START + 101);
        vm.prank(stranger);
        vm.expectRevert("Not bounty creator");
        bb.claimExpiredBounty(id);
    }

    function test_ClaimExpired_NotOpenReverts() public {
        uint256 id = _createWithDeadline(START + 100);
        _submit(alice, id);
        _approve(id, alice);
        vm.warp(START + 101);
        vm.prank(creator);
        vm.expectRevert("Bounty not open");
        bb.claimExpiredBounty(id);
    }

    function test_ClaimExpired_TwiceReverts() public {
        uint256 id = _createWithDeadline(START + 100);
        vm.warp(START + 101);
        vm.startPrank(creator);
        bb.claimExpiredBounty(id);
        vm.expectRevert("Bounty not open");
        bb.claimExpiredBounty(id);
        vm.stopPrank();
    }

    // ---------------- emergency ----------------

    function test_SetEmergencyMode_NonOwnerReverts() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
        bb.setEmergencyMode(true);
    }

    function test_EmergencyRefund_NotInEmergencyReverts() public {
        uint256 id = _create();
        vm.prank(owner);
        vm.expectRevert("Emergency mode inactive");
        bb.emergencyRefund(id);
    }

    function test_EmergencyRefund_NonOwnerReverts() public {
        uint256 id = _create();
        vm.prank(owner);
        bb.setEmergencyMode(true);
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
        bb.emergencyRefund(id);
    }

    function test_EmergencyRefund_CreatorCannotCall() public {
        uint256 id = _create();
        vm.prank(owner);
        bb.setEmergencyMode(true);
        vm.prank(creator);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, creator));
        bb.emergencyRefund(id);
    }

    function test_EmergencyRefund_UnknownIdReverts() public {
        vm.startPrank(owner);
        bb.setEmergencyMode(true);
        vm.expectRevert("Invalid bounty id");
        bb.emergencyRefund(UNKNOWN);
        vm.stopPrank();
    }

    function test_EmergencyRefund_NotOpenReverts() public {
        uint256 id = _createClaimed();
        vm.startPrank(owner);
        bb.setEmergencyMode(true);
        vm.expectRevert("Bounty not open");
        bb.emergencyRefund(id);
        vm.stopPrank();
    }

    function test_EmergencyRefund_TwiceReverts() public {
        uint256 id = _create();
        vm.startPrank(owner);
        bb.setEmergencyMode(true);
        bb.emergencyRefund(id);
        vm.expectRevert("Bounty not open");
        bb.emergencyRefund(id);
        vm.stopPrank();
    }

    // ---------------- views ----------------

    function test_GetBounty_UnknownIdReverts() public {
        vm.expectRevert("Invalid bounty id");
        bb.getBounty(0);
    }

    function test_GetSubmissions_UnknownIdReverts() public {
        vm.expectRevert("Invalid bounty id");
        bb.getSubmissions(0);
    }

    // ---------------- documented griefing behaviour ----------------

    /// A single (even worthless) submission permanently blocks cancelBounty on a
    /// no-deadline bounty unless the submitter voluntarily withdraws.
    function test_Cancel_SpamSubmissionBlocksCancelOnNoDeadlineBounty() public {
        uint256 id = _create();
        _submit(stranger, id);
        vm.prank(creator);
        vm.expectRevert("Submissions exist");
        bb.cancelBounty(id);
        // and claimExpiredBounty is unavailable without a deadline
        vm.prank(creator);
        vm.expectRevert("Bounty not expired");
        bb.claimExpiredBounty(id);
    }
}
