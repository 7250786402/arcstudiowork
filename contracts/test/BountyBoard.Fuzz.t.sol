// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BountyBoardTestBase} from "./BountyBoard.Base.t.sol";
import {BountyBoard} from "../BountyBoard.sol";

contract BountyBoardFuzzTest is BountyBoardTestBase {
    function testFuzz_Create_EscrowsExactReward(uint256 reward, uint8 bType, uint256 dlOffset) public {
        reward = bound(reward, 1, FUNDS);
        bType = uint8(bound(bType, 0, 2));
        dlOffset = bound(dlOffset, 0, 3650 days);
        uint256 dl = dlOffset == 0 ? 0 : START + dlOffset;

        uint256 id = _createWith(reward, dl, bType);

        assertEq(_bal(address(bb)), reward);
        assertEq(_bal(creator), FUNDS - reward);
        assertEq(bb.getBounty(id).reward, reward);
        assertEq(bb.getBounty(id).deadline, dl);
    }

    function testFuzz_Create_InvalidTypeReverts(uint8 bType) public {
        bType = uint8(bound(bType, 3, 255));
        vm.prank(creator);
        vm.expectRevert("Invalid bounty type");
        bb.createBounty("t", "d", 1, "", 0, "", bType, 0);
    }

    function testFuzz_Create_PastOrNowDeadlineReverts(uint256 dl) public {
        dl = bound(dl, 1, START);
        vm.prank(creator);
        vm.expectRevert("Invalid deadline");
        bb.createBounty("t", "d", 1, "", dl, "", 0, 0);
    }

    function testFuzz_Approve_PayoutEqualsReward(uint256 reward) public {
        reward = bound(reward, 1, FUNDS);
        uint256 id = _createWith(reward, 0, 0);
        _submit(alice, id);
        uint256 before = _bal(alice);
        _approve(id, alice);

        assertEq(_bal(alice) - before, reward);
        assertEq(_bal(address(bb)), 0);
        assertEq(bb.totalEarned(alice), reward);
        assertEq(bb.bountiesWon(alice), 1);
    }

    function testFuzz_Cancel_RefundsExactReward(uint256 reward) public {
        reward = bound(reward, 1, FUNDS);
        uint256 id = _createWith(reward, 0, 0);
        vm.prank(creator);
        bb.cancelBounty(id);
        assertEq(_bal(creator), FUNDS);
        assertEq(_bal(address(bb)), 0);
    }

    function testFuzz_Expiry_Boundary(uint256 offset, uint256 delta) public {
        offset = bound(offset, 1, 365 days);
        delta = bound(delta, 0, 730 days);
        uint256 dl = START + offset;
        uint256 id = _createWithDeadline(dl);
        vm.warp(START + delta);

        vm.prank(creator);
        if (block.timestamp > dl) {
            bb.claimExpiredBounty(id);
            assertEq(_bal(creator), FUNDS);
        } else {
            vm.expectRevert("Bounty not expired");
            bb.claimExpiredBounty(id);
            assertEq(_bal(creator), FUNDS - REWARD);
        }
    }

    function testFuzz_Submit_DeadlineBoundary(uint256 offset, uint256 delta) public {
        offset = bound(offset, 1, 365 days);
        delta = bound(delta, 0, 730 days);
        uint256 dl = START + offset;
        uint256 id = _createWithDeadline(dl);
        vm.warp(START + delta);

        vm.prank(alice);
        if (block.timestamp > dl) {
            vm.expectRevert("Bounty deadline passed");
            bb.submitWork(id, "x");
        } else {
            bb.submitWork(id, "x");
            assertEq(_subs(id).length, 1);
        }
    }

    function testFuzz_Tip_AddsExactAmount(uint256 reward, uint256 tip) public {
        reward = bound(reward, 1, FUNDS);
        tip = bound(tip, 1, FUNDS);
        uint256 id = _createWith(reward, 0, 0);
        _submit(alice, id);
        _approve(id, alice);

        uint256 aliceBefore = _bal(alice);
        vm.prank(tipper);
        bb.tipWinner(id, tip);

        assertEq(_bal(alice) - aliceBefore, tip);
        assertEq(_bal(tipper), FUNDS - tip);
        assertEq(bb.totalEarned(alice), reward + tip);
        assertEq(bb.bountiesWon(alice), 1);
        assertEq(_bal(address(bb)), 0);
    }

    function testFuzz_Counts_CreatedAndSubmissions(uint8 nBounties, uint8 nSubs) public {
        uint256 nb = bound(nBounties, 1, 10);
        uint256 ns = bound(nSubs, 0, 20);
        uint256 total;
        for (uint256 i = 0; i < nb; i++) {
            _create();
            total += REWARD;
        }
        assertEq(bb.bountiesCreated(creator), nb);
        assertEq(bb.getBounties().length, nb);
        assertEq(_bal(address(bb)), total);

        for (uint256 i = 0; i < ns; i++) {
            address s = address(uint160(0x10000 + i));
            _submit(s, 0);
        }
        assertEq(_subs(0).length, ns);
    }

    /// Withdrawing any submitter leaves exactly the others (as a set), each exactly once.
    function testFuzz_Withdraw_KeepsOthers(uint8 nSubs, uint8 pick) public {
        uint256 n = bound(nSubs, 1, 20);
        uint256 p = bound(pick, 0, n - 1);
        uint256 id = _create();
        address[] memory subs = new address[](n);
        for (uint256 i = 0; i < n; i++) {
            subs[i] = address(uint160(0x20000 + i));
            _submit(subs[i], id);
        }
        vm.prank(subs[p]);
        bb.withdrawSubmission(id);

        BountyBoard.Submission[] memory s = _subs(id);
        assertEq(s.length, n - 1);
        for (uint256 i = 0; i < n; i++) {
            bool found;
            for (uint256 j = 0; j < s.length; j++) {
                if (s[j].submitter == subs[i]) found = true;
            }
            assertEq(found, i != p);
        }
        // withdrawn submitter may resubmit, others may not
        _submit(subs[p], id);
        assertEq(_subs(id).length, n);
    }
}
