// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Vm} from "forge-std/Vm.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EscrowDealTestBase} from "./EscrowDeal.Base.t.sol";
import {EscrowDeal} from "../EscrowDeal.sol";
import {MockBlockableERC20} from "../test-helpers/MockBlockableERC20.sol";

/// Accepted / SellerWithdrawn / ResolvedClaimed events: args, amounts, and emission before the transfer.
contract EscrowDealEventsTest is EscrowDealTestBase {
    bytes32 internal constant TRANSFER_SIG = keccak256("Transfer(address,address,uint256)");

    function _find(Vm.Log[] memory logs, address emitter, bytes32 sig) internal pure returns (uint256) {
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].emitter == emitter && logs[i].topics.length > 0 && logs[i].topics[0] == sig) return i;
        }
        return type(uint256).max;
    }

    function _assertBefore(Vm.Log[] memory logs, bytes32 sig) internal view {
        uint256 e = _find(logs, address(escrow), sig);
        uint256 t = _find(logs, USDC, TRANSFER_SIG);
        assertTrue(e != type(uint256).max, "event missing");
        assertTrue(t != type(uint256).max, "transfer missing");
        assertLt(e, t, "event must precede transfer");
    }

    function _blockableEtch() internal returns (MockBlockableERC20 t) {
        MockBlockableERC20 impl = new MockBlockableERC20();
        vm.etch(USDC, address(impl).code);
        t = MockBlockableERC20(USDC);
    }

    // ---------------- Accepted ----------------

    function test_Accepted_EmitsIdSellerPayout() public {
        uint256 id = _create(arbiter, WINDOW);
        vm.expectEmit(true, true, false, true, address(escrow));
        emit EscrowDeal.Accepted(id, seller, payout2);
        vm.prank(seller);
        escrow.acceptDeal(id, payout2);
    }

    function test_Accepted_PayoutDiffersFromSellerInEvent() public {
        uint256 id = _create(arbiter, WINDOW);
        vm.recordLogs();
        vm.prank(seller);
        escrow.acceptDeal(id, payout);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 i = _find(logs, address(escrow), EscrowDeal.Accepted.selector);
        assertTrue(i != type(uint256).max);
        assertEq(logs[i].topics.length, 3);
        assertEq(uint256(logs[i].topics[1]), id);
        assertEq(address(uint160(uint256(logs[i].topics[2]))), seller);
        assertEq(abi.decode(logs[i].data, (address)), payout);
    }

    function test_Accepted_NotEmittedOnRevert() public {
        uint256 id = _create(arbiter, WINDOW);
        vm.prank(stranger);
        vm.expectRevert(bytes("Not seller"));
        escrow.acceptDeal(id, payout);
        assertEq(uint8(_status(id)), uint8(EscrowDeal.Status.Funded));
    }

    // ---------------- SellerWithdrawn ----------------

    function test_SellerWithdrawn_ArgsAndAmount() public {
        uint256 id = _createAccepted(arbiter, WINDOW);
        vm.prank(buyer);
        escrow.release(id);

        vm.expectEmit(true, true, false, true, address(escrow));
        emit EscrowDeal.SellerWithdrawn(id, payout, AMOUNT);
        escrow.withdrawSeller(id);
        assertEq(_bal(payout), AMOUNT);
    }

    function test_SellerWithdrawn_UsesUpdatedPayoutAsBeneficiary() public {
        uint256 id = _createAccepted(arbiter, WINDOW);
        vm.prank(buyer);
        escrow.release(id);
        vm.prank(seller);
        escrow.updatePayout(id, payout2);

        vm.expectEmit(true, true, false, true, address(escrow));
        emit EscrowDeal.SellerWithdrawn(id, payout2, AMOUNT);
        escrow.withdrawSeller(id);
        assertEq(_bal(payout2), AMOUNT);
    }

    function test_SellerWithdrawn_EmittedBeforeTransfer() public {
        uint256 id = _createAccepted(arbiter, WINDOW);
        vm.prank(buyer);
        escrow.release(id);
        vm.recordLogs();
        escrow.withdrawSeller(id);
        _assertBefore(vm.getRecordedLogs(), EscrowDeal.SellerWithdrawn.selector);
    }

    function test_SellerWithdrawn_AfterAutoRelease() public {
        uint256 id = _createDelivered(address(0), WINDOW);
        skip(WINDOW + 1);
        vm.prank(seller);
        escrow.claimAfterReviewWindow(id);
        vm.expectEmit(true, true, false, true, address(escrow));
        emit EscrowDeal.SellerWithdrawn(id, payout, AMOUNT);
        escrow.withdrawSeller(id);
    }

    function test_SellerWithdrawn_FailedTransferRollsBackCredit() public {
        uint256 id = _createAccepted(arbiter, WINDOW);
        vm.prank(buyer);
        escrow.release(id);
        MockBlockableERC20 t = _blockableEtch();
        t.setBlock(payout, 1);

        vm.expectRevert(bytes("blocked"));
        escrow.withdrawSeller(id);
        assertEq(escrow.sellerOwed(id), AMOUNT);
        assertEq(_bal(address(escrow)), AMOUNT);

        // seller redirects to a clean payout and collects
        vm.prank(seller);
        escrow.updatePayout(id, payout2);
        escrow.withdrawSeller(id);
        assertEq(_bal(payout2), AMOUNT);
        assertEq(escrow.sellerOwed(id), 0);
    }

    function test_SellerWithdrawn_FalseReturnRollsBackCredit() public {
        uint256 id = _createAccepted(arbiter, WINDOW);
        vm.prank(buyer);
        escrow.release(id);
        MockBlockableERC20 t = _blockableEtch();
        t.setBlock(payout, 2);
        vm.expectRevert(abi.encodeWithSelector(SafeERC20.SafeERC20FailedOperation.selector, USDC));
        escrow.withdrawSeller(id);
        assertEq(escrow.sellerOwed(id), AMOUNT);
    }

    // ---------------- ResolvedClaimed ----------------

    function test_ResolvedClaimed_SellerSelfClaim() public {
        uint256 id = _createDisputed();
        vm.prank(arbiter);
        escrow.resolveDispute(id, 300e6);

        vm.expectEmit(true, true, false, true, address(escrow));
        emit EscrowDeal.ResolvedClaimed(id, seller, 300e6);
        vm.prank(seller);
        escrow.claimResolved(id);
        assertEq(_bal(payout), 300e6);
    }

    function test_ResolvedClaimed_BuyerSelfClaim() public {
        uint256 id = _createDisputed();
        vm.prank(arbiter);
        escrow.resolveDispute(id, 300e6);
        uint256 before_ = _bal(buyer);

        vm.expectEmit(true, true, false, true, address(escrow));
        emit EscrowDeal.ResolvedClaimed(id, buyer, 700e6);
        vm.prank(buyer);
        escrow.claimResolved(id);
        assertEq(_bal(buyer), before_ + 700e6);
    }

    function test_ResolvedClaimed_BeneficiaryIsSellerNotPayout_ThirdParty() public {
        uint256 id = _createDisputed();
        vm.prank(arbiter);
        escrow.resolveDispute(id, 400e6);
        vm.prank(seller);
        escrow.updatePayout(id, payout2);

        vm.expectEmit(true, true, false, true, address(escrow));
        emit EscrowDeal.ResolvedClaimed(id, seller, 400e6);
        vm.prank(stranger);
        escrow.claimResolved(id, seller);
        assertEq(_bal(payout2), 400e6);
        assertEq(_bal(seller), 0);

        vm.expectEmit(true, true, false, true, address(escrow));
        emit EscrowDeal.ResolvedClaimed(id, buyer, 600e6);
        vm.prank(stranger);
        escrow.claimResolved(id, buyer);
        assertEq(_bal(address(escrow)), 0);
    }

    function test_ResolvedClaimed_EmittedBeforeTransfer_BothOverloads() public {
        uint256 id = _createDisputed();
        vm.prank(arbiter);
        escrow.resolveDispute(id, 500e6);

        vm.recordLogs();
        vm.prank(seller);
        escrow.claimResolved(id);
        _assertBefore(vm.getRecordedLogs(), EscrowDeal.ResolvedClaimed.selector);

        vm.recordLogs();
        escrow.claimResolved(id, buyer);
        _assertBefore(vm.getRecordedLogs(), EscrowDeal.ResolvedClaimed.selector);
    }

    function test_ResolvedClaimed_NothingToClaimRevertsWithoutAccountingChange() public {
        uint256 id = _createDisputed();
        vm.prank(arbiter);
        escrow.resolveDispute(id, AMOUNT);
        vm.prank(buyer);
        vm.expectRevert(bytes("Nothing to claim"));
        escrow.claimResolved(id);
        // the reverted call must not have changed any accounting
        assertEq(escrow.claimableOf(id, seller), AMOUNT);
    }

    function test_ResolvedClaimed_FailedTransferKeepsClaimable() public {
        uint256 id = _createDisputed();
        vm.prank(arbiter);
        escrow.resolveDispute(id, 250e6);
        MockBlockableERC20 t = _blockableEtch();
        t.setBlock(payout, 1);

        vm.prank(seller);
        vm.expectRevert(bytes("blocked"));
        escrow.claimResolved(id);
        assertEq(escrow.claimableOf(id, seller), 250e6);
        assertEq(escrow.claimableOf(id, buyer), 750e6);
        assertEq(_bal(address(escrow)), AMOUNT);

        // the buyer's side is unaffected by the seller's payout being blocked
        escrow.claimResolved(id, buyer);
        assertEq(escrow.claimableOf(id, buyer), 0);
        assertEq(_bal(address(escrow)), 250e6);
    }

    // ---------------- fuzz ----------------

    function testFuzz_ResolvedClaimed_AmountsMatchSplit(uint256 sellerAmount) public {
        sellerAmount = bound(sellerAmount, 1, AMOUNT - 1);
        uint256 id = _createDisputed();
        vm.prank(arbiter);
        escrow.resolveDispute(id, sellerAmount);

        vm.expectEmit(true, true, false, true, address(escrow));
        emit EscrowDeal.ResolvedClaimed(id, seller, sellerAmount);
        escrow.claimResolved(id, seller);
        vm.expectEmit(true, true, false, true, address(escrow));
        emit EscrowDeal.ResolvedClaimed(id, buyer, AMOUNT - sellerAmount);
        escrow.claimResolved(id, buyer);
        assertEq(_bal(address(escrow)), 0);
    }

    function testFuzz_SellerWithdrawn_AmountMatchesDeal(uint256 amount) public {
        amount = bound(amount, 1, 1e24);
        usdc.mint(buyer, amount);
        vm.prank(buyer);
        uint256 id = escrow.createDeal(seller, amount, "t", "x", deliverBy, arbiter, 0);
        vm.prank(seller);
        escrow.acceptDeal(id, payout);
        vm.prank(buyer);
        escrow.release(id);

        vm.expectEmit(true, true, false, true, address(escrow));
        emit EscrowDeal.SellerWithdrawn(id, payout, amount);
        escrow.withdrawSeller(id);
        assertEq(_bal(payout), amount);
    }
}
