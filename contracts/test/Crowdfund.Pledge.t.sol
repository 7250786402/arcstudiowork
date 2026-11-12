// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CrowdfundTestBase} from "./Crowdfund.Base.t.sol";
import {Crowdfund} from "../Crowdfund.sol";

contract CrowdfundPledgeTest is CrowdfundTestBase {
    uint256 internal id;

    function setUp() public override {
        super.setUp();
        id = _create();
    }

    // ---- pledge --------------------------------------------------------

    function test_PledgeMovesFundsAndUpdatesAccounting() public {
        uint256 aliceBefore = _bal(alice);
        _pledge(alice, id, 300e6);
        assertEq(_bal(alice), aliceBefore - 300e6);
        assertEq(_bal(address(cf)), 300e6);
        assertEq(cf.getCampaign(id).raised, 300e6);
        assertEq(cf.pledgeOf(id, alice), 300e6);
        assertEq(cf.pledgeOf(id, bob), 0);
    }

    function test_PledgeEmitsEvent() public {
        vm.expectEmit(true, true, false, true, address(cf));
        emit Pledged(id, alice, 123e6);
        _pledge(alice, id, 123e6);
    }

    function test_MultipleBackersAccumulate() public {
        _pledge(alice, id, 300e6);
        _pledge(bob, id, 200e6);
        assertEq(cf.getCampaign(id).raised, 500e6);
        assertEq(_bal(address(cf)), 500e6);
        assertEq(cf.pledgeOf(id, alice), 300e6);
        assertEq(cf.pledgeOf(id, bob), 200e6);
    }

    function test_BackedByPushedOnlyOnFirstPledge() public {
        _pledge(alice, id, 100e6);
        _pledge(alice, id, 50e6);
        _pledge(alice, id, 25e6);
        uint256[] memory list = cf.backedBy(alice);
        assertEq(list.length, 1);
        assertEq(list[0], id);
        assertEq(cf.pledgeOf(id, alice), 175e6);
        assertEq(cf.backedBy(bob).length, 0);
    }

    function test_BackedByTracksMultipleCampaigns() public {
        uint256 id2 = _create();
        _pledge(alice, id2, 1);
        _pledge(alice, id, 1);
        _pledge(alice, id2, 1);
        uint256[] memory list = cf.backedBy(alice);
        assertEq(list.length, 2);
        assertEq(list[0], id2);
        assertEq(list[1], id);
    }

    function test_OverfundingAllowed() public {
        _pledge(alice, id, GOAL * 3);
        assertEq(cf.getCampaign(id).raised, GOAL * 3);
        assertEq(cf.pledgeOf(id, alice), GOAL * 3);
    }

    function test_PledgeAllowedAtDeadlineMinusOne() public {
        vm.warp(_deadline(id) - 1);
        _pledge(alice, id, 1);
        assertEq(cf.pledgeOf(id, alice), 1);
    }

    function test_RevertWhen_UnknownId() public {
        vm.expectRevert(bytes("Invalid campaign id"));
        vm.prank(alice);
        cf.pledge(99, 1);
    }

    function test_RevertWhen_ZeroAmount() public {
        vm.expectRevert(bytes("Amount is zero"));
        vm.prank(alice);
        cf.pledge(id, 0);
    }

    function test_RevertWhen_AtDeadline() public {
        vm.warp(_deadline(id));
        vm.expectRevert(bytes("Campaign ended"));
        vm.prank(alice);
        cf.pledge(id, 1);
    }

    function test_RevertWhen_AfterDeadline() public {
        vm.warp(_deadline(id) + 1 days);
        vm.expectRevert(bytes("Campaign ended"));
        vm.prank(alice);
        cf.pledge(id, 1);
    }

    function test_RevertWhen_Cancelled() public {
        vm.prank(creator);
        cf.cancelCampaign(id);
        vm.expectRevert(bytes("Campaign cancelled"));
        vm.prank(alice);
        cf.pledge(id, 1);
    }

    function test_RevertWhen_NoAllowance() public {
        vm.prank(alice);
        usdc.approve(address(cf), 0);
        vm.expectRevert();
        vm.prank(alice);
        cf.pledge(id, 1);
        assertEq(cf.getCampaign(id).raised, 0);
        assertEq(cf.backedBy(alice).length, 0);
    }

    function test_RevertWhen_InsufficientAllowance() public {
        vm.prank(alice);
        usdc.approve(address(cf), 10);
        vm.expectRevert();
        vm.prank(alice);
        cf.pledge(id, 11);
    }

    function test_RevertWhen_NoBalance() public {
        usdc.mint(stranger, 5);
        vm.prank(stranger);
        usdc.approve(address(cf), type(uint256).max);
        vm.expectRevert();
        vm.prank(stranger);
        cf.pledge(id, 6);
        assertEq(cf.pledgeOf(id, stranger), 0);
        assertEq(cf.backedBy(stranger).length, 0);
    }

    // ---- statusOf ------------------------------------------------------

    function test_Status_ActiveBeforeDeadline() public {
        assertEq(uint8(_status(id)), uint8(Crowdfund.Status.Active));
        vm.warp(_deadline(id) - 1);
        assertEq(uint8(_status(id)), uint8(Crowdfund.Status.Active));
    }

    function test_Status_ActiveEvenWhenGoalMet() public {
        _pledge(alice, id, GOAL);
        assertEq(uint8(_status(id)), uint8(Crowdfund.Status.Active));
        vm.warp(_deadline(id) - 1);
        assertEq(uint8(_status(id)), uint8(Crowdfund.Status.Active));
    }

    function test_Status_SucceededAtDeadline() public {
        _pledge(alice, id, GOAL);
        vm.warp(_deadline(id));
        assertEq(uint8(_status(id)), uint8(Crowdfund.Status.Succeeded));
    }

    function test_Status_SucceededAtGoalExactlyVsOneShort() public {
        uint256 id2 = _create();
        _pledge(alice, id, GOAL - 1);
        _pledge(alice, id2, GOAL);
        vm.warp(_deadline(id));
        assertEq(uint8(_status(id)), uint8(Crowdfund.Status.Failed));
        assertEq(uint8(_status(id2)), uint8(Crowdfund.Status.Succeeded));
    }

    function test_Status_FailedAtDeadlineWithNoPledges() public {
        vm.warp(_deadline(id) - 1);
        assertEq(uint8(_status(id)), uint8(Crowdfund.Status.Active));
        vm.warp(_deadline(id));
        assertEq(uint8(_status(id)), uint8(Crowdfund.Status.Failed));
    }

    function test_Status_Withdrawn() public {
        _pledge(alice, id, GOAL);
        vm.warp(_deadline(id));
        cf.withdrawFunds(id);
        assertEq(uint8(_status(id)), uint8(Crowdfund.Status.Withdrawn));
    }

    function test_Status_CancelledBeforeAndAfterDeadline() public {
        vm.prank(creator);
        cf.cancelCampaign(id);
        assertEq(uint8(_status(id)), uint8(Crowdfund.Status.Cancelled));
        vm.warp(_deadline(id) + 1);
        assertEq(uint8(_status(id)), uint8(Crowdfund.Status.Cancelled));
    }

    function test_Status_RevertsOnUnknownId() public {
        vm.expectRevert(bytes("Invalid campaign id"));
        cf.statusOf(5);
    }

    function test_PledgeOfRevertsOnUnknownId() public {
        vm.expectRevert(bytes("Invalid campaign id"));
        cf.pledgeOf(5, alice);
    }
}
