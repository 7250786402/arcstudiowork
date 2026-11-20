// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BountyBoardTestBase} from "./BountyBoard.Base.t.sol";
import {BountyBoard} from "../BountyBoard.sol";

/// withdrawSubmission with the O(1) index map (swap-and-pop).
contract BountyBoardIndexTest is BountyBoardTestBase {
    address internal dave = makeAddr("dave");

    function _order(uint256 id) internal view returns (address[] memory out) {
        BountyBoard.Submission[] memory s = _subs(id);
        out = new address[](s.length);
        for (uint256 i = 0; i < s.length; i++) {
            out[i] = s[i].submitter;
        }
    }

    function _withdraw(address who, uint256 id) internal {
        vm.prank(who);
        bb.withdrawSubmission(id);
    }

    function _four(uint256 id) internal {
        _submit(alice, id);
        _submit(bob, id);
        _submit(carol, id);
        _submit(dave, id);
    }

    // ---------------- first / middle / last ----------------

    function test_Index_RemoveFirst_LastMovesToFront() public {
        uint256 id = _create();
        _four(id);
        _withdraw(alice, id);
        address[] memory o = _order(id);
        assertEq(o.length, 3);
        assertEq(o[0], dave);
        assertEq(o[1], bob);
        assertEq(o[2], carol);
    }

    function test_Index_RemoveMiddle_LastMovesIntoSlot() public {
        uint256 id = _create();
        _four(id);
        _withdraw(bob, id);
        address[] memory o = _order(id);
        assertEq(o.length, 3);
        assertEq(o[0], alice);
        assertEq(o[1], dave);
        assertEq(o[2], carol);
    }

    function test_Index_RemoveLast_JustPops() public {
        uint256 id = _create();
        _four(id);
        _withdraw(dave, id);
        address[] memory o = _order(id);
        assertEq(o.length, 3);
        assertEq(o[0], alice);
        assertEq(o[1], bob);
        assertEq(o[2], carol);
    }

    function test_Index_MovedSubmitterCanStillWithdraw() public {
        uint256 id = _create();
        _four(id);
        _withdraw(alice, id); // dave now at index 0
        _withdraw(dave, id); // must find dave's NEW index (0), not 3
        address[] memory o = _order(id);
        assertEq(o.length, 2);
        assertEq(o[0], carol);
        assertEq(o[1], bob);
    }

    function test_Index_MovedSubmitterKeepsNote() public {
        uint256 id = _create();
        vm.prank(alice);
        bb.submitWork(id, "A");
        vm.prank(bob);
        bb.submitWork(id, "B");
        vm.prank(carol);
        bb.submitWork(id, "C");
        _withdraw(alice, id);
        BountyBoard.Submission[] memory s = _subs(id);
        assertEq(s[0].submitter, carol);
        assertEq(s[0].submissionNote, "C");
        assertEq(s[1].submitter, bob);
        assertEq(s[1].submissionNote, "B");
    }

    function test_Index_WithdrawOnlySubmission() public {
        uint256 id = _create();
        _submit(alice, id);
        _withdraw(alice, id);
        assertEq(_subs(id).length, 0);
        vm.prank(alice);
        vm.expectRevert("No submission found");
        bb.withdrawSubmission(id);
    }

    // ---------------- resubmit ----------------

    function test_Index_ResubmitAppendsAtEnd() public {
        uint256 id = _create();
        _four(id);
        _withdraw(alice, id);
        _submit(alice, id);
        address[] memory o = _order(id);
        assertEq(o.length, 4);
        assertEq(o[3], alice);
        // alice can withdraw again, at her new index
        _withdraw(alice, id);
        assertEq(_subs(id).length, 3);
    }

    function test_Index_ResubmitAfterBeingLast() public {
        uint256 id = _create();
        _submit(alice, id);
        _submit(bob, id);
        _withdraw(bob, id);
        _submit(bob, id);
        _withdraw(alice, id);
        address[] memory o = _order(id);
        assertEq(o.length, 1);
        assertEq(o[0], bob);
        _withdraw(bob, id);
        assertEq(_subs(id).length, 0);
    }

    function test_Index_ResubmittedCanBeApproved() public {
        uint256 id = _create();
        _four(id);
        _withdraw(bob, id);
        _submit(bob, id);
        _approve(id, bob);
        assertEq(bb.getBounty(id).claimer, bob);
    }

    function test_Index_WithdrawnCannotBeApproved_MovedCanBe() public {
        uint256 id = _create();
        _four(id);
        _withdraw(alice, id);
        vm.prank(creator);
        vm.expectRevert("Claimer has no submission");
        bb.approveClaimer(id, alice);
        _approve(id, dave); // dave was swapped into index 0
        assertEq(bb.getBounty(id).claimer, dave);
    }

    function test_Index_AfterWithdrawAllCancelWorks() public {
        uint256 id = _create();
        _four(id);
        _withdraw(carol, id);
        _withdraw(alice, id);
        _withdraw(dave, id);
        _withdraw(bob, id);
        assertEq(_subs(id).length, 0);
        vm.prank(creator);
        bb.cancelBounty(id);
        assertEq(_bal(creator), FUNDS);
    }

    function test_Index_IsPerBounty() public {
        uint256 a = _create();
        uint256 b = _create();
        _submit(alice, a);
        _submit(bob, a);
        _submit(bob, b);
        _submit(alice, b);
        _withdraw(alice, a); // bob moves to index 0 in bounty a only
        assertEq(_order(a)[0], bob);
        address[] memory ob = _order(b);
        assertEq(ob[0], bob);
        assertEq(ob[1], alice);
        _withdraw(bob, b);
        assertEq(_order(b)[0], alice);
        assertEq(_order(a)[0], bob);
    }

    // ---------------- fuzz ----------------

    /// Random removal order of N submitters: the remaining set is always exactly the
    /// not-yet-withdrawn submitters, each once, and each can still withdraw.
    function testFuzz_Index_RandomWithdrawOrder(uint8 nSubs, uint256 seed) public {
        uint256 n = bound(nSubs, 1, 24);
        uint256 id = _create();
        address[] memory all = new address[](n);
        bool[] memory live = new bool[](n);
        for (uint256 i = 0; i < n; i++) {
            all[i] = address(uint160(0x30000 + i));
            live[i] = true;
            _submit(all[i], id);
        }
        uint256 remaining = n;
        while (remaining > 0) {
            seed = uint256(keccak256(abi.encode(seed)));
            // pick the k-th live submitter
            uint256 k = seed % remaining;
            uint256 pick;
            for (uint256 i = 0; i < n; i++) {
                if (live[i]) {
                    if (k == 0) {
                        pick = i;
                        break;
                    }
                    k--;
                }
            }
            _withdraw(all[pick], id);
            live[pick] = false;
            remaining--;

            BountyBoard.Submission[] memory s = _subs(id);
            assertEq(s.length, remaining);
            for (uint256 i = 0; i < n; i++) {
                uint256 count;
                for (uint256 j = 0; j < s.length; j++) {
                    if (s[j].submitter == all[i]) count++;
                }
                assertEq(count, live[i] ? 1 : 0);
            }
        }
    }

    /// Random interleaving of submit / withdraw / resubmit against a reference model.
    function testFuzz_Index_RandomSubmitWithdrawMatchesModel(uint256 seed, uint8 steps) public {
        uint256 n = 8;
        uint256 id = _create();
        bool[] memory live = new bool[](n);
        uint256 liveCount;
        uint256 total = bound(steps, 1, 60);
        for (uint256 s = 0; s < total; s++) {
            seed = uint256(keccak256(abi.encode(seed, s)));
            uint256 who = seed % n;
            address a = address(uint160(0x40000 + who));
            if (live[who]) {
                _withdraw(a, id);
                live[who] = false;
                liveCount--;
            } else {
                _submit(a, id);
                live[who] = true;
                liveCount++;
            }
            BountyBoard.Submission[] memory subs = _subs(id);
            assertEq(subs.length, liveCount);
            for (uint256 i = 0; i < n; i++) {
                address ai = address(uint160(0x40000 + i));
                uint256 count;
                for (uint256 j = 0; j < subs.length; j++) {
                    if (subs[j].submitter == ai) count++;
                }
                assertEq(count, live[i] ? 1 : 0);
            }
        }
        // every remaining submitter is still individually withdrawable
        for (uint256 i = 0; i < n; i++) {
            if (live[i]) {
                _withdraw(address(uint160(0x40000 + i)), id);
                liveCount--;
                assertEq(_subs(id).length, liveCount);
            }
        }
        assertEq(_subs(id).length, 0);
    }

    /// After a random withdrawal, any remaining submitter is still approvable and paid.
    function testFuzz_Index_RemainingSubmitterApprovable(uint8 nSubs, uint8 removePick, uint8 approvePick) public {
        uint256 n = bound(nSubs, 2, 16);
        uint256 r = bound(removePick, 0, n - 1);
        uint256 id = _create();
        address[] memory all = new address[](n);
        for (uint256 i = 0; i < n; i++) {
            all[i] = address(uint160(0x50000 + i));
            _submit(all[i], id);
        }
        _withdraw(all[r], id);
        uint256 a = bound(approvePick, 0, n - 1);
        if (a == r) a = (a + 1) % n;
        _approve(id, all[a]);
        assertEq(_bal(all[a]), REWARD);
        assertEq(bb.getBounty(id).claimer, all[a]);
    }
}
