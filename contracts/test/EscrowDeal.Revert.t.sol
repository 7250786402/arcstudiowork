// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {EscrowDealTestBase} from "./EscrowDeal.Base.t.sol";
import {EscrowDeal} from "../EscrowDeal.sol";

contract EscrowDealRevertTest is EscrowDealTestBase {
    // ---------------- createDeal ----------------

    function _expectCreateRevert(
        string memory reason,
        address _seller,
        uint256 amount,
        uint256 _deliverBy,
        address arb,
        uint256 window
    ) internal {
        vm.prank(buyer);
        vm.expectRevert(bytes(reason));
        escrow.createDeal(_seller, amount, "t", "x", _deliverBy, arb, window);
    }

    function test_RevertCreate_SellerZero() public {
        _expectCreateRevert("Seller is zero", address(0), AMOUNT, deliverBy, arbiter, 0);
    }

    function test_RevertCreate_SellerIsBuyer() public {
        _expectCreateRevert("Seller is buyer", buyer, AMOUNT, deliverBy, arbiter, 0);
    }

    function test_RevertCreate_SellerIsEscrow() public {
        _expectCreateRevert("Seller is escrow", address(escrow), AMOUNT, deliverBy, arbiter, 0);
    }

    function test_RevertCreate_AmountZero() public {
        _expectCreateRevert("Amount is zero", seller, 0, deliverBy, arbiter, 0);
    }

    function test_RevertCreate_DeadlineNotInFuture() public {
        _expectCreateRevert("Invalid delivery deadline", seller, AMOUNT, block.timestamp, arbiter, 0);
    }

    function test_RevertCreate_ArbiterIsBuyer() public {
        _expectCreateRevert("Invalid arbiter", seller, AMOUNT, deliverBy, buyer, 0);
    }

    function test_RevertCreate_ArbiterIsSeller() public {
        _expectCreateRevert("Invalid arbiter", seller, AMOUNT, deliverBy, seller, 0);
    }

    function test_RevertCreate_WindowTooShort() public {
        _expectCreateRevert("Invalid review window", seller, AMOUNT, deliverBy, arbiter, 1 days - 1);
    }

    function test_RevertCreate_WindowTooLong() public {
        _expectCreateRevert("Invalid review window", seller, AMOUNT, deliverBy, arbiter, 30 days + 1);
    }

    function test_RevertCreate_NoArbiterAndNoReviewWindow() public {
        _expectCreateRevert("No settlement path", seller, AMOUNT, deliverBy, address(0), 0);
    }

    function test_RevertCreate_WithoutApproval() public {
        address poor = makeAddr("poor");
        usdc.mint(poor, AMOUNT);
        vm.prank(poor);
        vm.expectRevert();
        escrow.createDeal(seller, AMOUNT, "t", "x", deliverBy, arbiter, 0);
    }

    function test_RevertCreate_InsufficientBalance() public {
        vm.prank(buyer);
        vm.expectRevert();
        escrow.createDeal(seller, 1_000_000e6, "t", "x", deliverBy, arbiter, 0);
    }

    // ---------------- invalid id ----------------

    function test_RevertInvalidDealId() public {
        vm.expectRevert(bytes("Invalid deal id"));
        escrow.getDeal(0);
        vm.prank(seller);
        vm.expectRevert(bytes("Invalid deal id"));
        escrow.acceptDeal(5, payout);
        vm.prank(buyer);
        vm.expectRevert(bytes("Invalid deal id"));
        escrow.release(0);
        vm.expectRevert(bytes("Invalid deal id"));
        escrow.withdrawSeller(0);
    }

    // ---------------- acceptDeal ----------------

    function test_RevertAccept_NotSeller() public {
        uint256 id = _create(arbiter, WINDOW);
        vm.prank(stranger);
        vm.expectRevert(bytes("Not seller"));
        escrow.acceptDeal(id, payout);
        vm.prank(buyer);
        vm.expectRevert(bytes("Not seller"));
        escrow.acceptDeal(id, payout);
    }

    function test_RevertAccept_WrongStatus() public {
        uint256 id = _createAccepted(arbiter, WINDOW);
        vm.prank(seller);
        vm.expectRevert(bytes("Invalid status"));
        escrow.acceptDeal(id, payout);
    }

    function test_RevertAccept_DeadlinePassed() public {
        uint256 id = _create(arbiter, WINDOW);
        vm.warp(deliverBy + 1);
        vm.prank(seller);
        vm.expectRevert(bytes("Delivery deadline passed"));
        escrow.acceptDeal(id, payout);
    }

    function test_RevertAccept_PayoutZero() public {
        uint256 id = _create(arbiter, WINDOW);
        vm.prank(seller);
        vm.expectRevert(bytes("Payout is zero"));
        escrow.acceptDeal(id, address(0));
    }

    function test_RevertAccept_PayoutEscrow() public {
        uint256 id = _create(arbiter, WINDOW);
        vm.prank(seller);
        vm.expectRevert(bytes("Payout is escrow"));
        escrow.acceptDeal(id, address(escrow));
    }

    function test_RevertAccept_PayoutUsdc() public {
        uint256 id = _create(arbiter, WINDOW);
        vm.prank(seller);
        vm.expectRevert(bytes("Payout is USDC"));
        escrow.acceptDeal(id, USDC);
    }

    function test_RevertAccept_PayoutPrecompileRange() public {
        uint256 id = _create(arbiter, WINDOW);
        vm.prank(seller);
        vm.expectRevert(bytes("Payout in precompile range"));
        escrow.acceptDeal(id, address(uint160(0xFFFF)));
    }

    // ---------------- updatePayout ----------------

    function test_RevertUpdatePayout_NotSeller() public {
        uint256 id = _createAccepted(arbiter, WINDOW);
        vm.prank(buyer);
        vm.expectRevert(bytes("Not seller"));
        escrow.updatePayout(id, payout2);
    }

    function test_RevertUpdatePayout_StatusFunded() public {
        uint256 id = _create(arbiter, WINDOW);
        vm.prank(seller);
        vm.expectRevert(bytes("Invalid status"));
        escrow.updatePayout(id, payout2);
    }

    function test_RevertUpdatePayout_InvalidAddresses() public {
        uint256 id = _createAccepted(arbiter, WINDOW);
        vm.startPrank(seller);
        vm.expectRevert(bytes("Payout is zero"));
        escrow.updatePayout(id, address(0));
        vm.expectRevert(bytes("Payout is escrow"));
        escrow.updatePayout(id, address(escrow));
        vm.expectRevert(bytes("Payout is USDC"));
        escrow.updatePayout(id, USDC);
        vm.expectRevert(bytes("Payout in precompile range"));
        escrow.updatePayout(id, address(uint160(1)));
        vm.stopPrank();
    }

    // ---------------- cancelUnaccepted ----------------

    function test_RevertCancel_NotBuyer() public {
        uint256 id = _create(arbiter, WINDOW);
        vm.prank(seller);
        vm.expectRevert(bytes("Not buyer"));
        escrow.cancelUnaccepted(id);
    }

    function test_RevertCancel_AfterAccept() public {
        uint256 id = _createAccepted(arbiter, WINDOW);
        vm.prank(buyer);
        vm.expectRevert(bytes("Invalid status"));
        escrow.cancelUnaccepted(id);
    }

    function test_RevertCancel_Twice() public {
        uint256 id = _create(arbiter, WINDOW);
        vm.startPrank(buyer);
        escrow.cancelUnaccepted(id);
        vm.expectRevert(bytes("Invalid status"));
        escrow.cancelUnaccepted(id);
        vm.stopPrank();
    }

    // ---------------- markDelivered ----------------

    function test_RevertMarkDelivered_NotSeller() public {
        uint256 id = _createAccepted(arbiter, WINDOW);
        vm.prank(buyer);
        vm.expectRevert(bytes("Not seller"));
        escrow.markDelivered(id);
    }

    function test_RevertMarkDelivered_WrongStatus() public {
        uint256 id = _create(arbiter, WINDOW);
        vm.prank(seller);
        vm.expectRevert(bytes("Invalid status"));
        escrow.markDelivered(id);
    }

    function test_RevertMarkDelivered_DeadlinePassed() public {
        uint256 id = _createAccepted(arbiter, WINDOW);
        vm.warp(deliverBy + 1);
        vm.prank(seller);
        vm.expectRevert(bytes("Delivery deadline passed"));
        escrow.markDelivered(id);
    }

    // ---------------- release / withdrawSeller ----------------

    function test_RevertRelease_NotBuyer() public {
        uint256 id = _createAccepted(arbiter, WINDOW);
        vm.prank(seller);
        vm.expectRevert(bytes("Not buyer"));
        escrow.release(id);
    }

    function test_RevertRelease_WrongStatus() public {
        uint256 id = _create(arbiter, WINDOW);
        vm.prank(buyer);
        vm.expectRevert(bytes("Invalid status"));
        escrow.release(id);
    }

    function test_RevertRelease_Twice() public {
        uint256 id = _createAccepted(arbiter, WINDOW);
        vm.startPrank(buyer);
        escrow.release(id);
        vm.expectRevert(bytes("Invalid status"));
        escrow.release(id);
        vm.stopPrank();
    }

    function test_RevertWithdrawSeller_BeforeRelease() public {
        uint256 id = _createDelivered(arbiter, WINDOW);
        vm.expectRevert(bytes("Invalid status"));
        escrow.withdrawSeller(id);
    }

    function test_RevertWithdrawSeller_Double() public {
        uint256 id = _createAccepted(arbiter, WINDOW);
        vm.prank(buyer);
        escrow.release(id);
        escrow.withdrawSeller(id);
        vm.expectRevert(bytes("Nothing to claim"));
        escrow.withdrawSeller(id);
        assertEq(_bal(payout), AMOUNT);
    }

    // ---------------- refund ----------------

    function test_RevertRefund_NotSeller() public {
        uint256 id = _createAccepted(arbiter, WINDOW);
        vm.prank(buyer);
        vm.expectRevert(bytes("Not seller"));
        escrow.refund(id);
    }

    function test_RevertRefund_WrongStatus() public {
        uint256 id = _create(arbiter, WINDOW);
        vm.prank(seller);
        vm.expectRevert(bytes("Invalid status"));
        escrow.refund(id);
    }

    function test_RevertRefund_AfterRelease() public {
        uint256 id = _createAccepted(arbiter, WINDOW);
        vm.prank(buyer);
        escrow.release(id);
        vm.prank(seller);
        vm.expectRevert(bytes("Invalid status"));
        escrow.refund(id);
    }

    // ---------------- reclaimExpired ----------------

    function test_RevertReclaim_NotBuyer() public {
        uint256 id = _create(arbiter, WINDOW);
        vm.warp(deliverBy + 1);
        vm.prank(seller);
        vm.expectRevert(bytes("Not buyer"));
        escrow.reclaimExpired(id);
    }

    function test_RevertReclaim_BeforeDeadline() public {
        uint256 id = _create(arbiter, WINDOW);
        vm.prank(buyer);
        vm.expectRevert(bytes("Delivery deadline not passed"));
        escrow.reclaimExpired(id);
    }

    function test_RevertReclaim_AtExactDeadline() public {
        uint256 id = _create(arbiter, WINDOW);
        vm.warp(deliverBy);
        vm.prank(buyer);
        vm.expectRevert(bytes("Delivery deadline not passed"));
        escrow.reclaimExpired(id);
    }

    function test_RevertReclaim_WhenDelivered() public {
        uint256 id = _createDelivered(arbiter, WINDOW);
        vm.warp(deliverBy + 1);
        vm.prank(buyer);
        vm.expectRevert(bytes("Invalid status"));
        escrow.reclaimExpired(id);
    }

    // ---------------- claimAfterReviewWindow ----------------

    function test_RevertClaimAfterWindow_NotSeller() public {
        uint256 id = _createDelivered(address(0), WINDOW);
        skip(WINDOW + 1);
        vm.prank(buyer);
        vm.expectRevert(bytes("Not seller"));
        escrow.claimAfterReviewWindow(id);
    }

    function test_RevertClaimAfterWindow_NotDelivered() public {
        uint256 id = _createAccepted(address(0), WINDOW);
        skip(WINDOW + 1);
        vm.prank(seller);
        vm.expectRevert(bytes("Invalid status"));
        escrow.claimAfterReviewWindow(id);
    }

    function test_RevertClaimAfterWindow_AutoReleaseDisabled() public {
        uint256 id = _createDelivered(arbiter, 0);
        skip(365 days);
        vm.prank(seller);
        vm.expectRevert(bytes("Auto-release disabled"));
        escrow.claimAfterReviewWindow(id);
    }

    function test_RevertClaimAfterWindow_DisputedDealCannotAutoRelease() public {
        uint256 id = _createDisputed();
        skip(WINDOW + 1);
        vm.prank(seller);
        vm.expectRevert(bytes("Invalid status"));
        escrow.claimAfterReviewWindow(id);
    }

    function test_RevertClaimAfterWindow_Twice() public {
        uint256 id = _createDelivered(address(0), WINDOW);
        skip(WINDOW + 1);
        vm.startPrank(seller);
        escrow.claimAfterReviewWindow(id);
        vm.expectRevert(bytes("Invalid status"));
        escrow.claimAfterReviewWindow(id);
        vm.stopPrank();
    }

    // ---------------- raiseDispute ----------------

    function test_RevertRaiseDispute_Stranger() public {
        uint256 id = _createDelivered(arbiter, WINDOW);
        vm.prank(stranger);
        vm.expectRevert(bytes("Not buyer or seller"));
        escrow.raiseDispute(id);
    }

    function test_RevertRaiseDispute_ArbiterCannotRaise() public {
        uint256 id = _createDelivered(arbiter, WINDOW);
        vm.prank(arbiter);
        vm.expectRevert(bytes("Not buyer or seller"));
        escrow.raiseDispute(id);
    }

    function test_RevertRaiseDispute_NotDelivered() public {
        uint256 id = _createAccepted(arbiter, WINDOW);
        vm.prank(buyer);
        vm.expectRevert(bytes("Invalid status"));
        escrow.raiseDispute(id);
    }

    function test_RevertRaiseDispute_BuyerAfterWindow() public {
        uint256 id = _createDelivered(arbiter, WINDOW);
        skip(WINDOW + 1);
        vm.prank(buyer);
        vm.expectRevert(bytes("Review window passed"));
        escrow.raiseDispute(id);
    }

    function test_RevertRaiseDispute_NoArbiter() public {
        uint256 id = _createDelivered(address(0), WINDOW);
        vm.prank(buyer);
        vm.expectRevert(bytes("No arbiter"));
        escrow.raiseDispute(id);
        vm.prank(seller);
        vm.expectRevert(bytes("No arbiter"));
        escrow.raiseDispute(id);
    }

    function test_RevertRaiseDispute_Twice() public {
        uint256 id = _createDisputed();
        vm.prank(seller);
        vm.expectRevert(bytes("Invalid status"));
        escrow.raiseDispute(id);
    }

    // ---------------- resolveDispute ----------------

    function test_RevertResolve_NotArbiter() public {
        uint256 id = _createDisputed();
        vm.prank(buyer);
        vm.expectRevert(bytes("Not arbiter"));
        escrow.resolveDispute(id, 0);
        vm.prank(seller);
        vm.expectRevert(bytes("Not arbiter"));
        escrow.resolveDispute(id, AMOUNT);
        vm.prank(stranger);
        vm.expectRevert(bytes("Not arbiter"));
        escrow.resolveDispute(id, 1);
    }

    function test_RevertResolve_NotDisputed() public {
        uint256 id = _createDelivered(arbiter, WINDOW);
        vm.prank(arbiter);
        vm.expectRevert(bytes("Invalid status"));
        escrow.resolveDispute(id, 0);
    }

    function test_RevertResolve_AmountAboveDealAmount() public {
        uint256 id = _createDisputed();
        vm.prank(arbiter);
        vm.expectRevert(bytes("Exceeds escrow amount"));
        escrow.resolveDispute(id, AMOUNT + 1);
    }

    function test_RevertResolve_Twice() public {
        uint256 id = _createDisputed();
        vm.startPrank(arbiter);
        escrow.resolveDispute(id, 1);
        vm.expectRevert(bytes("Invalid status"));
        escrow.resolveDispute(id, 2);
        vm.stopPrank();
    }

    // ---------------- claimResolved ----------------

    function test_RevertClaimResolved_NotResolved() public {
        uint256 id = _createDisputed();
        vm.prank(buyer);
        vm.expectRevert(bytes("Invalid status"));
        escrow.claimResolved(id);
    }

    function test_RevertClaimResolved_Stranger() public {
        uint256 id = _createDisputed();
        vm.prank(arbiter);
        escrow.resolveDispute(id, 100e6);
        vm.prank(stranger);
        vm.expectRevert(bytes("Not buyer or seller"));
        escrow.claimResolved(id);
        vm.expectRevert(bytes("Not buyer or seller"));
        escrow.claimResolved(id, stranger);
        vm.expectRevert(bytes("Not buyer or seller"));
        escrow.claimResolved(id, arbiter);
    }

    function test_RevertClaimResolved_DoubleClaim() public {
        uint256 id = _createDisputed();
        vm.prank(arbiter);
        escrow.resolveDispute(id, 100e6);
        vm.startPrank(seller);
        escrow.claimResolved(id);
        vm.expectRevert(bytes("Nothing to claim"));
        escrow.claimResolved(id);
        vm.stopPrank();
        // other side's entitlement is untouched
        assertEq(escrow.claimableOf(id, buyer), AMOUNT - 100e6);
    }

    // ---------------- refundStaleDispute ----------------

    function test_RevertStale_NotBuyer() public {
        uint256 id = _createDisputed();
        skip(escrow.ARBITER_TIMEOUT() + 1);
        vm.prank(seller);
        vm.expectRevert(bytes("Not buyer"));
        escrow.refundStaleDispute(id);
    }

    function test_RevertStale_NotDisputed() public {
        uint256 id = _createDelivered(arbiter, WINDOW);
        vm.prank(buyer);
        vm.expectRevert(bytes("Invalid status"));
        escrow.refundStaleDispute(id);
    }

    function test_RevertStale_BeforeTimeout() public {
        uint256 id = _createDisputed();
        skip(escrow.ARBITER_TIMEOUT());
        vm.prank(buyer);
        vm.expectRevert(bytes("Arbiter timeout not passed"));
        escrow.refundStaleDispute(id);
    }

    function test_RevertStale_AfterArbiterResolved() public {
        uint256 id = _createDisputed();
        vm.prank(arbiter);
        escrow.resolveDispute(id, 1);
        skip(escrow.ARBITER_TIMEOUT() + 1);
        vm.prank(buyer);
        vm.expectRevert(bytes("Invalid status"));
        escrow.refundStaleDispute(id);
    }
}
