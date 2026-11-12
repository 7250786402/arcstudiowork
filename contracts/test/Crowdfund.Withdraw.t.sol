// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CrowdfundTestBase} from "./Crowdfund.Base.t.sol";
import {Crowdfund} from "../Crowdfund.sol";

contract CrowdfundWithdrawTest is CrowdfundTestBase {
    uint256 internal id;

    function setUp() public override {
        super.setUp();
        id = _create();
    }

    function _fundAndEnd() internal {
        _pledge(alice, id, 800e6);
        _pledge(bob, id, 700e6); // 1500 raised, overfunded
        vm.warp(_deadline(id));
    }

    // ---- withdrawFunds -------------------------------------------------

    function test_WithdrawPaysBeneficiaryFullRaised() public {
        _fundAndEnd();
        uint256 before = _bal(bene);
        cf.withdrawFunds(id);
        assertEq(_bal(bene), before + 1500e6);
        assertEq(_bal(address(cf)), 0);
        Crowdfund.Campaign memory c = cf.getCampaign(id);
        assertTrue(c.withdrawn);
        assertEq(c.raised, 1500e6);
    }

    function test_WithdrawEmitsEvent() public {
        _fundAndEnd();
        vm.expectEmit(true, true, false, true, address(cf));
        emit FundsWithdrawn(id, bene, 1500e6);
        cf.withdrawFunds(id);
    }

    function test_WithdrawCallableByAnyone() public {
        _fundAndEnd();
        vm.prank(stranger);
        cf.withdrawFunds(id);
        assertEq(_bal(bene), 1500e6);
        assertEq(_bal(stranger), 0);
    }

    function test_WithdrawCallableByCreatorAndBacker() public {
        _fundAndEnd();
        vm.prank(creator);
        cf.withdrawFunds(id);
        assertEq(_bal(bene), 1500e6);
    }

    function test_WithdrawAtExactGoal() public {
        _pledge(alice, id, GOAL);
        vm.warp(_deadline(id));
        cf.withdrawFunds(id);
        assertEq(_bal(bene), GOAL);
    }

    function test_RevertWhen_WithdrawUnknownId() public {
        vm.expectRevert(bytes("Invalid campaign id"));
        cf.withdrawFunds(7);
    }

    function test_RevertWhen_WithdrawBeforeDeadline() public {
        _pledge(alice, id, GOAL);
        vm.warp(_deadline(id) - 1);
        vm.expectRevert(bytes("Campaign still active"));
        cf.withdrawFunds(id);
    }

    function test_RevertWhen_WithdrawGoalMissed() public {
        _pledge(alice, id, GOAL - 1);
        vm.warp(_deadline(id));
        vm.expectRevert(bytes("Goal not reached"));
        cf.withdrawFunds(id);
    }

    function test_RevertWhen_WithdrawCancelled() public {
        _pledge(alice, id, GOAL);
        vm.prank(creator);
        cf.cancelCampaign(id);
        vm.warp(_deadline(id));
        vm.expectRevert(bytes("Campaign cancelled"));
        cf.withdrawFunds(id);
    }

    function test_RevertWhen_WithdrawTwice() public {
        _fundAndEnd();
        cf.withdrawFunds(id);
        vm.expectRevert(bytes("Funds already withdrawn"));
        cf.withdrawFunds(id);
    }

    // ---- updateBeneficiary ---------------------------------------------

    function test_UpdateBeneficiaryByCreator() public {
        vm.expectEmit(true, false, false, true, address(cf));
        emit BeneficiaryUpdated(id, bene2);
        vm.prank(creator);
        cf.updateBeneficiary(id, bene2);
        assertEq(cf.getCampaign(id).beneficiary, bene2);
    }

    function test_NewBeneficiaryReceivesWithdrawal() public {
        _fundAndEnd();
        // allowed after the deadline too, as long as not withdrawn
        vm.prank(creator);
        cf.updateBeneficiary(id, bene2);
        cf.withdrawFunds(id);
        assertEq(_bal(bene2), 1500e6);
        assertEq(_bal(bene), 0);
    }

    function test_RevertWhen_UpdateByNonCreator() public {
        vm.expectRevert(bytes("Not campaign creator"));
        vm.prank(stranger);
        cf.updateBeneficiary(id, bene2);
    }

    function test_RevertWhen_UpdateByCurrentBeneficiary() public {
        vm.expectRevert(bytes("Not campaign creator"));
        vm.prank(bene);
        cf.updateBeneficiary(id, bene2);
    }

    function test_RevertWhen_UpdateAfterWithdraw() public {
        _fundAndEnd();
        cf.withdrawFunds(id);
        vm.expectRevert(bytes("Funds already withdrawn"));
        vm.prank(creator);
        cf.updateBeneficiary(id, bene2);
    }

    function test_RevertWhen_UpdateUnknownId() public {
        vm.expectRevert(bytes("Invalid campaign id"));
        vm.prank(creator);
        cf.updateBeneficiary(42, bene2);
    }

    function test_RevertWhen_UpdateToZero() public {
        vm.expectRevert(bytes("Beneficiary is zero"));
        vm.prank(creator);
        cf.updateBeneficiary(id, address(0));
    }

    function test_RevertWhen_UpdateToCrowdfund() public {
        address self = address(cf);
        vm.expectRevert(bytes("Beneficiary is crowdfund"));
        vm.prank(creator);
        cf.updateBeneficiary(id, self);
    }

    function test_RevertWhen_UpdateToUsdc() public {
        vm.expectRevert(bytes("Beneficiary is USDC"));
        vm.prank(creator);
        cf.updateBeneficiary(id, USDC);
    }

    function test_RevertWhen_UpdateToReservedRange() public {
        vm.expectRevert(bytes("Beneficiary in reserved range"));
        vm.prank(creator);
        cf.updateBeneficiary(id, address(uint160(0xFFFF)));
    }

    function test_UpdateToLowestValidAddress() public {
        vm.prank(creator);
        cf.updateBeneficiary(id, address(uint160(0x10000)));
        assertEq(cf.getCampaign(id).beneficiary, address(uint160(0x10000)));
    }
}
