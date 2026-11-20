// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Vm} from "forge-std/Vm.sol";
import {BountyBoardTestBase} from "./BountyBoard.Base.t.sol";
import {BountyBoard} from "../BountyBoard.sol";
import {MockBlockableERC20} from "../test-helpers/MockBlockableERC20.sol";

/// Events are emitted before the USDC transfer; failed transfers leave no state behind.
/// (Logs of a reverted call cannot be observed in-EVM, and forge's recordLogs still captures them,
/// so revert + untouched state is the observable proof that nothing persisted.)
contract BountyBoardEventsTest is BountyBoardTestBase {
    bytes32 internal constant TRANSFER_SIG = keccak256("Transfer(address,address,uint256)");

    function _blockableEtch() internal returns (MockBlockableERC20 t) {
        MockBlockableERC20 impl = new MockBlockableERC20();
        vm.etch(USDC, address(impl).code);
        t = MockBlockableERC20(USDC);
    }

    /// index of first log from `emitter` with topic0 == sig, or type(uint256).max
    function _find(Vm.Log[] memory logs, address emitter, bytes32 sig) internal pure returns (uint256) {
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].emitter == emitter && logs[i].topics.length > 0 && logs[i].topics[0] == sig) return i;
        }
        return type(uint256).max;
    }

    function _assertEventBeforeTransfer(Vm.Log[] memory logs, bytes32 sig) internal view {
        uint256 e = _find(logs, address(bb), sig);
        uint256 t = _find(logs, USDC, TRANSFER_SIG);
        assertTrue(e != type(uint256).max, "bounty event missing");
        assertTrue(t != type(uint256).max, "transfer event missing");
        assertLt(e, t, "event must precede USDC transfer");
    }

    // ---------------- ordering ----------------

    function test_Order_BountyCreatedBeforeTransferFrom() public {
        vm.recordLogs();
        _create();
        _assertEventBeforeTransfer(vm.getRecordedLogs(), BountyCreated.selector);
    }

    function test_Order_BountyClaimedBeforeTransfer() public {
        uint256 id = _create();
        _submit(alice, id);
        vm.recordLogs();
        _approve(id, alice);
        _assertEventBeforeTransfer(vm.getRecordedLogs(), BountyClaimed.selector);
    }

    function test_Order_WinnerTippedBeforeTransferFrom() public {
        uint256 id = _createClaimed();
        vm.recordLogs();
        vm.prank(tipper);
        bb.tipWinner(id, 5e6);
        _assertEventBeforeTransfer(vm.getRecordedLogs(), WinnerTipped.selector);
    }

    function test_Order_BountyCancelledBeforeTransfer_Cancel() public {
        uint256 id = _create();
        vm.recordLogs();
        vm.prank(creator);
        bb.cancelBounty(id);
        _assertEventBeforeTransfer(vm.getRecordedLogs(), BountyCancelled.selector);
    }

    function test_Order_BountyCancelledBeforeTransfer_ClaimExpired() public {
        uint256 id = _create();
        vm.warp(DL + 1);
        vm.recordLogs();
        vm.prank(creator);
        bb.claimExpiredBounty(id);
        _assertEventBeforeTransfer(vm.getRecordedLogs(), BountyCancelled.selector);
    }

    function test_Order_BountyCancelledBeforeTransfer_EmergencyRefund() public {
        uint256 id = _create();
        vm.startPrank(owner);
        bb.setEmergencyMode(true);
        vm.recordLogs();
        bb.emergencyRefund(id);
        vm.stopPrank();
        _assertEventBeforeTransfer(vm.getRecordedLogs(), BountyCancelled.selector);
    }

    function test_Events_ApproveEmitsExactlyOneBountyClaimedWithArgs() public {
        uint256 id = _create();
        _submit(alice, id);
        vm.expectEmit(false, false, false, true, address(bb));
        emit BountyClaimed(id, alice, REWARD);
        _approve(id, alice);
    }

    // ---------------- failed transfers leave nothing behind ----------------

    function _bbLogCount(Vm.Log[] memory logs) internal view returns (uint256 c) {
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].emitter == address(bb)) c++;
        }
    }

    function test_Failed_Approve_TransferReverts_NoState() public {
        uint256 id = _create();
        _submit(alice, id);
        MockBlockableERC20 t = _blockableEtch();
        t.setBlock(alice, 1);

        vm.prank(creator);
        (bool ok, bytes memory ret) = address(bb).call(abi.encodeCall(BountyBoard.approveClaimer, (id, alice)));
        assertFalse(ok);
        assertEq(keccak256(ret), keccak256(abi.encodeWithSignature("Error(string)", "Winner address cannot receive USDC")));

        BountyBoard.Bounty memory b = bb.getBounty(id);
        assertEq(uint8(b.status), uint8(BountyBoard.BountyStatus.Open));
        assertEq(b.claimer, address(0));
        (uint256 earned, uint256 won,) = bb.getReputation(alice);
        assertEq(earned, 0);
        assertEq(won, 0);
        assertEq(_bal(address(bb)), REWARD);
        assertEq(_subs(id).length, 1);
    }

    function test_Failed_Approve_TransferReturnsFalse_NoState() public {
        uint256 id = _create();
        _submit(alice, id);
        MockBlockableERC20 t = _blockableEtch();
        t.setBlock(alice, 2);

        vm.prank(creator);
        (bool ok, bytes memory ret) = address(bb).call(abi.encodeCall(BountyBoard.approveClaimer, (id, alice)));
        assertFalse(ok);
        assertEq(keccak256(ret), keccak256(abi.encodeWithSignature("Error(string)", "Winner address cannot receive USDC")));

        assertEq(uint8(_status(id)), uint8(BountyBoard.BountyStatus.Open));
        assertEq(bb.getBounty(id).claimer, address(0));
        assertEq(bb.totalEarned(alice), 0);
        assertEq(bb.bountiesWon(alice), 0);
        assertEq(_bal(address(bb)), REWARD);
    }

    function test_Failed_Approve_ThenRetryEmitsSingleClaimedForNewWinner() public {
        uint256 id = _create();
        _submit(alice, id);
        _submit(bob, id);
        MockBlockableERC20 t = _blockableEtch();
        t.setBlock(alice, 2);

        vm.prank(creator);
        vm.expectRevert("Winner address cannot receive USDC");
        bb.approveClaimer(id, alice);

        vm.recordLogs();
        _approve(id, bob);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(_bbLogCount(logs), 1);
        assertEq(logs[_find(logs, address(bb), BountyClaimed.selector)].emitter, address(bb));
        assertEq(bb.bountiesWon(alice), 0);
        assertEq(bb.bountiesWon(bob), 1);
    }

    function test_Failed_Cancel_TransferReturnsFalse_StaysOpen() public {
        uint256 id = _create();
        MockBlockableERC20 t = _blockableEtch();
        t.setBlock(creator, 2);

        vm.prank(creator);
        (bool ok, bytes memory ret) = address(bb).call(abi.encodeCall(BountyBoard.cancelBounty, (id)));
        assertFalse(ok);
        assertEq(keccak256(ret), keccak256(abi.encodeWithSignature("Error(string)", "USDC transfer failed")));
        assertEq(uint8(_status(id)), uint8(BountyBoard.BountyStatus.Open));
        assertEq(_bal(address(bb)), REWARD);
    }

    function test_Failed_Cancel_TransferReverts_StaysOpen() public {
        uint256 id = _create();
        MockBlockableERC20 t = _blockableEtch();
        t.setBlock(creator, 1);

        vm.prank(creator);
        vm.expectRevert(bytes("blocked"));
        bb.cancelBounty(id);
        assertEq(uint8(_status(id)), uint8(BountyBoard.BountyStatus.Open));
        assertEq(_bal(address(bb)), REWARD);
    }

    function test_Failed_ClaimExpired_TransferFails_StaysOpen() public {
        uint256 id = _create();
        MockBlockableERC20 t = _blockableEtch();
        t.setBlock(creator, 2);
        vm.warp(DL + 1);

        vm.recordLogs();
        vm.prank(creator);
        (bool ok,) = address(bb).call(abi.encodeCall(BountyBoard.claimExpiredBounty, (id)));
        assertFalse(ok);
        assertEq(uint8(_status(id)), uint8(BountyBoard.BountyStatus.Open));

        // once the transfer can succeed again the creator recovers the reward
        t.setBlock(creator, 0);
        vm.prank(creator);
        bb.claimExpiredBounty(id);
        assertEq(_bal(creator), FUNDS);
    }

    function test_Failed_EmergencyRefund_TransferFails_StaysOpen() public {
        uint256 id = _create();
        MockBlockableERC20 t = _blockableEtch();
        t.setBlock(creator, 2);
        vm.startPrank(owner);
        bb.setEmergencyMode(true);
        vm.recordLogs();
        (bool ok,) = address(bb).call(abi.encodeCall(BountyBoard.emergencyRefund, (id)));
        vm.stopPrank();
        assertFalse(ok);
        assertEq(uint8(_status(id)), uint8(BountyBoard.BountyStatus.Open));
    }

    function test_Failed_Create_NoAllowance_NoBounty() public {
        address noApproval = makeAddr("noApproval");
        usdc.mint(noApproval, 100e6);
        vm.recordLogs();
        vm.prank(noApproval);
        (bool ok,) = address(bb).call(
            abi.encodeCall(BountyBoard.createBounty, ("t", "d", 1e6, "", DL, "", uint8(0), uint256(0)))
        );
        assertFalse(ok);
        assertEq(bb.getBounties().length, 0);
        assertEq(bb.bountiesCreated(noApproval), 0);
    }

    function test_Failed_Tip_NoAllowance_NoReputation() public {
        uint256 id = _createClaimed();
        address noApproval = makeAddr("noApproval");
        usdc.mint(noApproval, 10e6);
        uint256 earnedBefore = bb.totalEarned(alice);

        vm.recordLogs();
        vm.prank(noApproval);
        (bool ok,) = address(bb).call(abi.encodeCall(BountyBoard.tipWinner, (id, 1e6)));
        assertFalse(ok);
        assertEq(bb.totalEarned(alice), earnedBefore);
    }
}
