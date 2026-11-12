// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CrowdfundTestBase} from "./Crowdfund.Base.t.sol";
import {Crowdfund} from "../Crowdfund.sol";

contract CrowdfundFuzzTest is CrowdfundTestBase {
    function testFuzz_PledgeAmountsAccumulate(uint256 seed, uint8 countRaw) public {
        uint256 id = _create();
        uint256 count = bound(countRaw, 1, 12);
        uint256 total;
        uint256 aliceTotal;
        for (uint256 i = 0; i < count; i++) {
            uint256 amt = bound(uint256(keccak256(abi.encode(seed, i))), 1, 10_000e6);
            _pledge(alice, id, amt);
            total += amt;
            aliceTotal += amt;
        }
        assertEq(cf.getCampaign(id).raised, total);
        assertEq(cf.pledgeOf(id, alice), aliceTotal);
        assertEq(_bal(address(cf)), total);
        assertEq(_bal(alice), FUNDS - total);
        // backedBy has the campaign exactly once regardless of pledge count
        assertEq(cf.backedBy(alice).length, 1);
    }

    function testFuzz_MultiBackerRaisedIsSum(uint256 a, uint256 b, uint256 c) public {
        uint256 id = _create();
        a = bound(a, 1, FUNDS);
        b = bound(b, 1, FUNDS);
        c = bound(c, 1, FUNDS);
        _pledge(alice, id, a);
        _pledge(bob, id, b);
        _pledge(carol, id, c);
        assertEq(cf.getCampaign(id).raised, a + b + c);
        assertEq(_bal(address(cf)), a + b + c);
        assertEq(cf.pledgeOf(id, alice), a);
        assertEq(cf.pledgeOf(id, bob), b);
        assertEq(cf.pledgeOf(id, carol), c);
    }

    function testFuzz_FailedRefundReturnsExactlyPledged(uint256 a, uint256 b, uint256 c) public {
        a = bound(a, 1, 100_000e6);
        b = bound(b, 1, 100_000e6);
        c = bound(c, 1, 100_000e6);
        vm.prank(creator);
        uint256 id = cf.createCampaign("T", "D", a + b + c + 1, DURATION, bene);
        _pledge(alice, id, a);
        _pledge(bob, id, b);
        _pledge(carol, id, c);
        vm.warp(_deadline(id));

        vm.prank(alice);
        cf.refund(id);
        vm.prank(bob);
        cf.refund(id);
        vm.prank(carol);
        cf.refund(id);

        assertEq(_bal(alice), FUNDS);
        assertEq(_bal(bob), FUNDS);
        assertEq(_bal(carol), FUNDS);
        assertEq(_bal(address(cf)), 0);
        assertEq(cf.getCampaign(id).refunded, a + b + c);
    }

    function testFuzz_CancelledRefundReturnsExactlyPledged(uint256 a, uint256 b, uint256 elapsed) public {
        a = bound(a, 1, 1_000_000e6);
        b = bound(b, 1, 1_000_000e6);
        uint256 id = _create();
        _pledge(alice, id, a);
        _pledge(bob, id, b);
        elapsed = bound(elapsed, 0, DURATION - 1);
        vm.warp(START + elapsed);
        vm.prank(creator);
        cf.cancelCampaign(id);

        vm.prank(alice);
        cf.refund(id);
        vm.prank(bob);
        cf.refund(id);
        assertEq(_bal(alice), FUNDS);
        assertEq(_bal(bob), FUNDS);
        assertEq(_bal(address(cf)), 0);
    }

    function testFuzz_WithdrawPaysFullRaisedWhenGoalMet(uint256 a, uint256 b) public {
        a = bound(a, 1, 500_000e6);
        b = bound(b, 1, 500_000e6);
        vm.prank(creator);
        uint256 id = cf.createCampaign("T", "D", a + b, DURATION, bene);
        _pledge(alice, id, a);
        _pledge(bob, id, b);
        vm.warp(_deadline(id));
        cf.withdrawFunds(id);
        assertEq(_bal(bene), a + b);
        assertEq(_bal(address(cf)), 0);
    }

    function testFuzz_StatusBoundaryAroundDeadline(uint256 duration, bool met) public {
        duration = bound(duration, 1 hours, 90 days);
        vm.prank(creator);
        uint256 id = cf.createCampaign("T", "D", GOAL, duration, bene);
        if (met) _pledge(alice, id, GOAL);
        uint256 dl = START + duration;
        assertEq(cf.getCampaign(id).deadline, dl);
        vm.warp(dl - 1);
        assertEq(uint8(_status(id)), uint8(Crowdfund.Status.Active));
        vm.warp(dl);
        assertEq(uint8(_status(id)), uint8(met ? Crowdfund.Status.Succeeded : Crowdfund.Status.Failed));
    }

    function testFuzz_InvalidBeneficiaryBelowReservedReverts(uint160 raw) public {
        raw = uint160(bound(raw, 1, 0xFFFF));
        vm.expectRevert(bytes("Beneficiary in reserved range"));
        vm.prank(creator);
        cf.createCampaign("T", "D", GOAL, DURATION, address(raw));
    }
}
