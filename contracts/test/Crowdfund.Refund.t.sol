// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CrowdfundTestBase} from "./Crowdfund.Base.t.sol";
import {Crowdfund} from "../Crowdfund.sol";

contract CrowdfundRefundTest is CrowdfundTestBase {
    uint256 internal id;

    function setUp() public override {
        super.setUp();
        id = _create();
    }

    // ---- refund: failed campaign ---------------------------------------

    function test_RefundFailedCampaignExactAmounts() public {
        _pledge(alice, id, 300e6);
        _pledge(bob, id, 200e6);
        _pledge(alice, id, 50e6);
        vm.warp(_deadline(id));

        uint256 aBefore = _bal(alice);
        vm.prank(alice);
        cf.refund(id);
        assertEq(_bal(alice), aBefore + 350e6);
        assertEq(cf.pledgeOf(id, alice), 0);
        assertEq(cf.getCampaign(id).refunded, 350e6);
        assertEq(cf.getCampaign(id).raised, 550e6); // historical total unchanged
        assertEq(_bal(address(cf)), 200e6);

        uint256 bBefore = _bal(bob);
        vm.prank(bob);
        cf.refund(id);
        assertEq(_bal(bob), bBefore + 200e6);
        assertEq(_bal(address(cf)), 0);
        assertEq(cf.getCampaign(id).refunded, 550e6);
    }

    function test_RefundEmitsEvent() public {
        _pledge(alice, id, 300e6);
        vm.warp(_deadline(id));
        vm.expectEmit(true, true, false, true, address(cf));
        emit Refunded(id, alice, 300e6);
        vm.prank(alice);
        cf.refund(id);
    }

    function test_RefundAvailableExactlyAtDeadline() public {
        _pledge(alice, id, 10e6);
        vm.warp(_deadline(id) - 1);
        vm.expectRevert(bytes("Refund unavailable"));
        vm.prank(alice);
        cf.refund(id);
        vm.warp(_deadline(id));
        vm.prank(alice);
        cf.refund(id);
        assertEq(cf.pledgeOf(id, alice), 0);
    }

    function test_RefundFailedStatusStaysFailed() public {
        _pledge(alice, id, 10e6);
        vm.warp(_deadline(id));
        vm.prank(alice);
        cf.refund(id);
        assertEq(uint8(_status(id)), uint8(Crowdfund.Status.Failed));
    }

    // ---- refund: cancelled campaign ------------------------------------

    function test_RefundCancelledBeforeDeadline() public {
        _pledge(alice, id, GOAL); // goal even met; cancel still refunds
        _pledge(bob, id, 77e6);
        vm.prank(creator);
        cf.cancelCampaign(id);

        uint256 aBefore = _bal(alice);
        uint256 bBefore = _bal(bob);
        vm.prank(alice);
        cf.refund(id);
        vm.prank(bob);
        cf.refund(id);
        assertEq(_bal(alice), aBefore + GOAL);
        assertEq(_bal(bob), bBefore + 77e6);
        assertEq(_bal(address(cf)), 0);
    }

    function test_RefundCancelledAfterDeadline() public {
        _pledge(alice, id, GOAL);
        vm.prank(creator);
        cf.cancelCampaign(id);
        vm.warp(_deadline(id) + 10 days);
        vm.prank(alice);
        cf.refund(id);
        assertEq(_bal(alice), FUNDS);
    }

    // ---- refund reverts -------------------------------------------------

    function test_RevertWhen_RefundSuccessfulCampaign() public {
        _pledge(alice, id, GOAL);
        vm.warp(_deadline(id));
        vm.expectRevert(bytes("Refund unavailable"));
        vm.prank(alice);
        cf.refund(id);
    }

    function test_RevertWhen_RefundSuccessfulCampaignAfterWithdraw() public {
        _pledge(alice, id, GOAL);
        vm.warp(_deadline(id));
        cf.withdrawFunds(id);
        vm.expectRevert(bytes("Refund unavailable"));
        vm.prank(alice);
        cf.refund(id);
    }

    function test_RevertWhen_RefundLiveCampaign() public {
        _pledge(alice, id, 10e6);
        vm.expectRevert(bytes("Refund unavailable"));
        vm.prank(alice);
        cf.refund(id);
    }

    function test_RevertWhen_RefundUnknownId() public {
        vm.expectRevert(bytes("Invalid campaign id"));
        vm.prank(alice);
        cf.refund(9);
    }

    function test_RevertWhen_RefundZeroPledge() public {
        _pledge(alice, id, 10e6);
        vm.warp(_deadline(id));
        vm.expectRevert(bytes("Nothing to refund"));
        vm.prank(bob);
        cf.refund(id);
    }

    function test_RevertWhen_DoubleRefund() public {
        _pledge(alice, id, 10e6);
        vm.warp(_deadline(id));
        vm.prank(alice);
        cf.refund(id);
        vm.expectRevert(bytes("Nothing to refund"));
        vm.prank(alice);
        cf.refund(id);
    }

    function test_RefundDoesNotAffectOtherCampaign() public {
        uint256 id2 = _create();
        _pledge(alice, id, 10e6);
        _pledge(alice, id2, 20e6);
        vm.warp(_deadline(id));
        vm.prank(alice);
        cf.refund(id);
        assertEq(cf.pledgeOf(id2, alice), 20e6);
        assertEq(_bal(address(cf)), 20e6);
    }

    // ---- cancelCampaign ------------------------------------------------

    function test_CancelByCreator() public {
        vm.expectEmit(true, false, false, true, address(cf));
        emit CampaignCancelled(id);
        vm.prank(creator);
        cf.cancelCampaign(id);
        assertTrue(cf.getCampaign(id).cancelled);
        assertEq(uint8(_status(id)), uint8(Crowdfund.Status.Cancelled));
    }

    function test_CancelAtDeadlineMinusOne() public {
        vm.warp(_deadline(id) - 1);
        vm.prank(creator);
        cf.cancelCampaign(id);
        assertTrue(cf.getCampaign(id).cancelled);
    }

    function test_RevertWhen_CancelByNonCreator() public {
        vm.expectRevert(bytes("Not campaign creator"));
        vm.prank(stranger);
        cf.cancelCampaign(id);
    }

    function test_RevertWhen_CancelByBeneficiary() public {
        vm.expectRevert(bytes("Not campaign creator"));
        vm.prank(bene);
        cf.cancelCampaign(id);
    }

    function test_RevertWhen_CancelUnknownId() public {
        vm.expectRevert(bytes("Invalid campaign id"));
        vm.prank(creator);
        cf.cancelCampaign(5);
    }

    function test_RevertWhen_CancelAtDeadline() public {
        vm.warp(_deadline(id));
        vm.expectRevert(bytes("Campaign ended"));
        vm.prank(creator);
        cf.cancelCampaign(id);
    }

    function test_RevertWhen_CancelAfterDeadline() public {
        vm.warp(_deadline(id) + 1 days);
        vm.expectRevert(bytes("Campaign ended"));
        vm.prank(creator);
        cf.cancelCampaign(id);
    }

    function test_RevertWhen_CancelTwice() public {
        vm.prank(creator);
        cf.cancelCampaign(id);
        vm.expectRevert(bytes("Campaign already cancelled"));
        vm.prank(creator);
        cf.cancelCampaign(id);
    }

    function test_RevertWhen_CancelAfterWithdraw() public {
        // Withdraw requires deadline passed, so the deadline check fires first.
        _pledge(alice, id, GOAL);
        vm.warp(_deadline(id));
        cf.withdrawFunds(id);
        vm.expectRevert(bytes("Campaign ended"));
        vm.prank(creator);
        cf.cancelCampaign(id);
    }
}
