// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Vm} from "forge-std/Vm.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EscrowDealTestBase} from "./EscrowDeal.Base.t.sol";
import {EscrowDeal} from "../EscrowDeal.sol";
import {MockBlockableERC20} from "../test-helpers/MockBlockableERC20.sol";

/// Seller-initiated refund is credit-only; withdrawBuyer pays out. Other refund paths stay direct.
contract EscrowDealBuyerTest is EscrowDealTestBase {
    bytes32 internal constant TRANSFER_SIG = keccak256("Transfer(address,address,uint256)");

    function _blockableEtch() internal returns (MockBlockableERC20 t) {
        MockBlockableERC20 impl = new MockBlockableERC20();
        vm.etch(USDC, address(impl).code); // storage (balances, allowances) is preserved
        t = MockBlockableERC20(USDC);
    }

    function _find(Vm.Log[] memory logs, address emitter, bytes32 sig) internal pure returns (uint256) {
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].emitter == emitter && logs[i].topics.length > 0 && logs[i].topics[0] == sig) return i;
        }
        return type(uint256).max;
    }

    function _sellerRefund(uint256 id) internal {
        vm.prank(seller);
        escrow.refund(id);
    }

    // ---------------- refund(id): credit only ----------------

    function test_Refund_CreditsBuyerOwedAndDoesNotTransfer() public {
        uint256 id = _createAccepted(arbiter, WINDOW);
        uint256 buyerBefore = _bal(buyer);

        vm.recordLogs();
        _sellerRefund(id);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(_find(logs, USDC, TRANSFER_SIG), type(uint256).max, "refund must not move USDC");

        assertEq(uint8(_status(id)), uint8(EscrowDeal.Status.Refunded));
        assertEq(escrow.buyerOwed(id), AMOUNT);
        assertEq(_bal(buyer), buyerBefore);
        assertEq(_bal(address(escrow)), AMOUNT);
    }

    function test_Refund_FromDeliveredCredits() public {
        uint256 id = _createDelivered(arbiter, WINDOW);
        _sellerRefund(id);
        assertEq(escrow.buyerOwed(id), AMOUNT);
        assertEq(uint8(_status(id)), uint8(EscrowDeal.Status.Refunded));
    }

    function test_Refund_EmitsRefundedEvent() public {
        uint256 id = _createAccepted(arbiter, WINDOW);
        vm.expectEmit(true, true, false, true, address(escrow));
        emit EscrowDeal.Refunded(id, buyer, AMOUNT);
        _sellerRefund(id);
    }

    function test_Refund_TwiceReverts() public {
        uint256 id = _createAccepted(arbiter, WINDOW);
        _sellerRefund(id);
        vm.prank(seller);
        vm.expectRevert(bytes("Invalid status"));
        escrow.refund(id);
        assertEq(escrow.buyerOwed(id), AMOUNT);
    }

    // ---------------- withdrawBuyer ----------------

    function test_WithdrawBuyer_PaysBuyerZeroesFirstAndEmits() public {
        uint256 id = _createAccepted(arbiter, WINDOW);
        _sellerRefund(id);
        uint256 buyerBefore = _bal(buyer);

        vm.expectEmit(true, true, false, true, address(escrow));
        emit EscrowDeal.BuyerWithdrawn(id, buyer, AMOUNT);
        escrow.withdrawBuyer(id);

        assertEq(escrow.buyerOwed(id), 0);
        assertEq(_bal(buyer), buyerBefore + AMOUNT);
        assertEq(_bal(address(escrow)), 0);
        assertEq(uint8(_status(id)), uint8(EscrowDeal.Status.Refunded));
    }

    function test_WithdrawBuyer_CallableByAnyone_FundsGoToBuyer() public {
        uint256 id = _createAccepted(arbiter, WINDOW);
        _sellerRefund(id);
        uint256 buyerBefore = _bal(buyer);

        vm.prank(stranger);
        escrow.withdrawBuyer(id);
        assertEq(_bal(stranger), 0);
        assertEq(_bal(buyer), buyerBefore + AMOUNT);
    }

    function test_WithdrawBuyer_SellerCanTriggerToo() public {
        uint256 id = _createDelivered(arbiter, WINDOW);
        _sellerRefund(id);
        uint256 buyerBefore = _bal(buyer);
        vm.prank(seller);
        escrow.withdrawBuyer(id);
        assertEq(_bal(seller), 0);
        assertEq(_bal(payout), 0);
        assertEq(_bal(buyer), buyerBefore + AMOUNT);
    }

    function test_WithdrawBuyer_SecondCallReverts() public {
        uint256 id = _createAccepted(arbiter, WINDOW);
        _sellerRefund(id);
        escrow.withdrawBuyer(id);
        uint256 buyerBal = _bal(buyer);
        vm.expectRevert(bytes("Nothing to claim"));
        escrow.withdrawBuyer(id);
        assertEq(_bal(buyer), buyerBal);
    }

    function test_WithdrawBuyer_BuyerOwedIsZeroBeforeRefund() public {
        uint256 id = _createAccepted(arbiter, WINDOW);
        assertEq(escrow.buyerOwed(id), 0);
    }

    function test_WithdrawBuyer_InvalidIdReverts() public {
        vm.expectRevert(bytes("Invalid deal id"));
        escrow.withdrawBuyer(42);
    }

    function test_WithdrawBuyer_FundedReverts() public {
        uint256 id = _create(arbiter, WINDOW);
        vm.expectRevert(bytes("Invalid status"));
        escrow.withdrawBuyer(id);
    }

    function test_WithdrawBuyer_AcceptedAndDeliveredRevert() public {
        uint256 a = _createAccepted(arbiter, WINDOW);
        uint256 d = _createDelivered(arbiter, WINDOW);
        vm.expectRevert(bytes("Invalid status"));
        escrow.withdrawBuyer(a);
        vm.expectRevert(bytes("Invalid status"));
        escrow.withdrawBuyer(d);
    }

    function test_WithdrawBuyer_ReleasedReverts() public {
        uint256 id = _createAccepted(arbiter, WINDOW);
        vm.prank(buyer);
        escrow.release(id);
        vm.expectRevert(bytes("Invalid status"));
        escrow.withdrawBuyer(id);
    }

    function test_WithdrawBuyer_DisputedAndResolvedRevert() public {
        uint256 d = _createDisputed();
        vm.expectRevert(bytes("Invalid status"));
        escrow.withdrawBuyer(d);
        vm.prank(arbiter);
        escrow.resolveDispute(d, 0);
        vm.expectRevert(bytes("Invalid status"));
        escrow.withdrawBuyer(d);
    }

    function test_WithdrawBuyer_AfterDirectRefundHasNothingToClaim() public {
        // cancelUnaccepted pays directly, so there is no buyerOwed credit to withdraw
        uint256 id = _create(arbiter, WINDOW);
        vm.prank(buyer);
        escrow.cancelUnaccepted(id);
        assertEq(escrow.buyerOwed(id), 0);
        vm.expectRevert(bytes("Nothing to claim"));
        escrow.withdrawBuyer(id);
    }

    function test_WithdrawBuyer_EventEmittedBeforeTransfer() public {
        uint256 id = _createAccepted(arbiter, WINDOW);
        _sellerRefund(id);
        vm.recordLogs();
        escrow.withdrawBuyer(id);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 e = _find(logs, address(escrow), EscrowDeal.BuyerWithdrawn.selector);
        uint256 t = _find(logs, USDC, TRANSFER_SIG);
        assertTrue(e != type(uint256).max && t != type(uint256).max);
        assertLt(e, t);
    }

    function test_WithdrawBuyer_IndependentPerDeal() public {
        uint256 a = _createAccepted(arbiter, WINDOW);
        uint256 b = _createAccepted(arbiter, WINDOW);
        _sellerRefund(a);
        _sellerRefund(b);
        escrow.withdrawBuyer(a);
        assertEq(escrow.buyerOwed(a), 0);
        assertEq(escrow.buyerOwed(b), AMOUNT);
        assertEq(_bal(address(escrow)), AMOUNT);
    }

    // ---------------- no double payment after a seller refund ----------------

    function test_AfterSellerRefund_OtherRefundPathsRevert() public {
        uint256 id = _createAccepted(arbiter, WINDOW);
        _sellerRefund(id);
        vm.warp(deliverBy + 1);
        vm.startPrank(buyer);
        vm.expectRevert(bytes("Invalid status"));
        escrow.reclaimExpired(id);
        vm.expectRevert(bytes("Invalid status"));
        escrow.cancelUnaccepted(id);
        vm.expectRevert(bytes("Invalid status"));
        escrow.refundStaleDispute(id);
        vm.expectRevert(bytes("Invalid status"));
        escrow.release(id);
        vm.stopPrank();
        assertEq(_bal(address(escrow)), AMOUNT);
    }

    // ---------------- blocklisted buyer cannot block refund(id) ----------------

    function test_Blocklisted_Buyer_RevertMode_CannotBlockRefund() public {
        uint256 id = _createAccepted(arbiter, WINDOW);
        MockBlockableERC20 t = _blockableEtch();
        t.setBlock(buyer, 1);

        _sellerRefund(id); // must not revert
        assertEq(uint8(_status(id)), uint8(EscrowDeal.Status.Refunded));
        assertEq(escrow.buyerOwed(id), AMOUNT);

        vm.expectRevert(bytes("blocked"));
        escrow.withdrawBuyer(id);
        // failed payout rolled back: credit and funds intact
        assertEq(escrow.buyerOwed(id), AMOUNT);
        assertEq(_bal(address(escrow)), AMOUNT);

        t.setBlock(buyer, 0);
        uint256 before_ = _bal(buyer);
        escrow.withdrawBuyer(id);
        assertEq(_bal(buyer), before_ + AMOUNT);
        assertEq(escrow.buyerOwed(id), 0);
    }

    function test_Blocklisted_Buyer_FalseMode_CannotBlockRefund() public {
        uint256 id = _createDelivered(arbiter, WINDOW);
        MockBlockableERC20 t = _blockableEtch();
        t.setBlock(buyer, 2);

        _sellerRefund(id);
        assertEq(uint8(_status(id)), uint8(EscrowDeal.Status.Refunded));
        assertEq(escrow.buyerOwed(id), AMOUNT);

        vm.expectRevert(abi.encodeWithSelector(SafeERC20.SafeERC20FailedOperation.selector, USDC));
        escrow.withdrawBuyer(id);
        assertEq(escrow.buyerOwed(id), AMOUNT);
        assertEq(_bal(address(escrow)), AMOUNT);

        t.setBlock(buyer, 0);
        escrow.withdrawBuyer(id);
        assertEq(escrow.buyerOwed(id), 0);
        assertEq(_bal(address(escrow)), 0);
    }

    function test_Blocklisted_Buyer_DoesNotBlockSellerOtherDeals() public {
        uint256 a = _createAccepted(arbiter, WINDOW);
        uint256 b = _createAccepted(arbiter, WINDOW);
        MockBlockableERC20 t = _blockableEtch();
        t.setBlock(buyer, 1);

        _sellerRefund(a);
        // seller can still settle deal b (release by buyer, payout to non-blocked address)
        vm.prank(buyer);
        escrow.release(b);
        escrow.withdrawSeller(b);
        assertEq(_bal(payout), AMOUNT);
    }

    // ---------------- other buyer refunds remain direct ----------------

    function test_CancelUnaccepted_PaysDirectlyNoCredit() public {
        uint256 id = _create(arbiter, WINDOW);
        uint256 before_ = _bal(buyer);
        vm.prank(buyer);
        escrow.cancelUnaccepted(id);
        assertEq(_bal(buyer), before_ + AMOUNT);
        assertEq(escrow.buyerOwed(id), 0);
        assertEq(_bal(address(escrow)), 0);
    }

    function test_ReclaimExpired_PaysDirectlyNoCredit() public {
        uint256 id = _createAccepted(arbiter, WINDOW);
        uint256 before_ = _bal(buyer);
        vm.warp(deliverBy + 1);
        vm.prank(buyer);
        escrow.reclaimExpired(id);
        assertEq(_bal(buyer), before_ + AMOUNT);
        assertEq(escrow.buyerOwed(id), 0);
        assertEq(_bal(address(escrow)), 0);
    }

    function test_RefundStaleDispute_PaysDirectlyNoCredit() public {
        uint256 id = _createDisputed();
        uint256 before_ = _bal(buyer);
        skip(escrow.ARBITER_TIMEOUT() + 1);
        vm.prank(buyer);
        escrow.refundStaleDispute(id);
        assertEq(_bal(buyer), before_ + AMOUNT);
        assertEq(escrow.buyerOwed(id), 0);
        assertEq(_bal(address(escrow)), 0);
    }

    function test_DirectRefundPaths_BlockedBuyerFailsAtomically() public {
        // buyer-triggered refunds stay direct: if the buyer's own receipt fails the whole call reverts, state intact
        uint256 id = _create(arbiter, WINDOW);
        MockBlockableERC20 t = _blockableEtch();
        t.setBlock(buyer, 1);
        vm.prank(buyer);
        vm.expectRevert(bytes("blocked"));
        escrow.cancelUnaccepted(id);
        assertEq(uint8(_status(id)), uint8(EscrowDeal.Status.Funded));
        assertEq(_bal(address(escrow)), AMOUNT);
    }

    // ---------------- fuzz ----------------

    function testFuzz_RefundThenWithdraw_ExactAmount(uint256 amount, bool delivered, address caller) public {
        amount = bound(amount, 1, 1e24);
        vm.assume(caller != address(0) && caller != address(escrow) && caller != USDC);
        usdc.mint(buyer, amount);
        vm.prank(buyer);
        uint256 id = escrow.createDeal(seller, amount, "t", "x", deliverBy, arbiter, WINDOW);
        vm.startPrank(seller);
        escrow.acceptDeal(id, payout);
        if (delivered) escrow.markDelivered(id);
        escrow.refund(id);
        vm.stopPrank();

        assertEq(escrow.buyerOwed(id), amount);
        assertEq(_bal(address(escrow)), amount);

        uint256 buyerBefore = _bal(buyer);
        uint256 callerBefore = _bal(caller);
        vm.prank(caller);
        escrow.withdrawBuyer(id);
        assertEq(_bal(buyer) - buyerBefore, amount);
        if (caller != buyer) assertEq(_bal(caller), callerBefore);
        assertEq(escrow.buyerOwed(id), 0);
        assertEq(_bal(address(escrow)), 0);

        vm.prank(caller);
        vm.expectRevert(bytes("Nothing to claim"));
        escrow.withdrawBuyer(id);
    }
}
