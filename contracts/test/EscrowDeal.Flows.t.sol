// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {EscrowDealTestBase} from "./EscrowDeal.Base.t.sol";
import {EscrowDeal} from "../EscrowDeal.sol";

contract EscrowDealFlowsTest is EscrowDealTestBase {
    // ---------------- createDeal ----------------

    function test_CreateDeal_StoresDealAndEscrowsFunds() public {
        uint256 buyerBefore = _bal(buyer);
        vm.expectEmit(true, true, true, true, address(escrow));
        emit EscrowDeal.DealCreated(0, buyer, seller, AMOUNT);
        uint256 id = _create(arbiter, WINDOW);

        assertEq(id, 0);
        assertEq(escrow.dealCount(), 1);
        assertEq(_bal(address(escrow)), AMOUNT);
        assertEq(_bal(buyer), buyerBefore - AMOUNT);

        EscrowDeal.Deal memory d = escrow.getDeal(id);
        assertEq(d.buyer, buyer);
        assertEq(d.seller, seller);
        assertEq(d.arbiter, arbiter);
        assertEq(d.amount, AMOUNT);
        assertEq(d.title, "title");
        assertEq(d.terms, "terms");
        assertEq(d.deliverBy, deliverBy);
        assertEq(d.reviewWindow, WINDOW);
        assertEq(uint8(d.status), uint8(EscrowDeal.Status.Funded));

        assertEq(escrow.dealsOf(buyer).length, 1);
        assertEq(escrow.dealsOf(seller).length, 1);
        assertEq(escrow.dealsOf(arbiter).length, 1);
    }

    function test_CreateDeal_ArbiterOnlyAndWindowOnlyAllowed() public {
        uint256 a = _create(arbiter, 0);
        uint256 b = _create(address(0), 1 days);
        uint256 c = _create(address(0), 30 days);
        assertEq(a, 0);
        assertEq(b, 1);
        assertEq(c, 2);
        assertEq(escrow.dealsOf(arbiter).length, 1);
        assertEq(escrow.dealsOf(buyer).length, 3);
    }

    // ---------------- accept / deliver / release / withdraw ----------------

    function test_AcceptDeal_SetsPayoutAndStatus() public {
        uint256 id = _create(arbiter, WINDOW);
        vm.prank(seller);
        escrow.acceptDeal(id, payout);
        EscrowDeal.Deal memory d = escrow.getDeal(id);
        assertEq(d.sellerPayout, payout);
        assertEq(uint8(d.status), uint8(EscrowDeal.Status.Accepted));
    }

    function test_AcceptDeal_AtExactDeadlineAllowed() public {
        uint256 id = _create(arbiter, WINDOW);
        vm.warp(deliverBy);
        vm.prank(seller);
        escrow.acceptDeal(id, payout);
        assertEq(uint8(_status(id)), uint8(EscrowDeal.Status.Accepted));
    }

    function test_AcceptDeal_PayoutAtLowestAllowedAddress() public {
        uint256 id = _create(arbiter, WINDOW);
        vm.prank(seller);
        escrow.acceptDeal(id, address(uint160(0x10000)));
        assertEq(escrow.getDeal(id).sellerPayout, address(uint160(0x10000)));
    }

    function test_MarkDelivered_SetsTimestampAndEmits() public {
        uint256 id = _createAccepted(arbiter, WINDOW);
        skip(1 days);
        vm.expectEmit(true, false, false, false, address(escrow));
        emit EscrowDeal.Delivered(id);
        vm.prank(seller);
        escrow.markDelivered(id);
        EscrowDeal.Deal memory d = escrow.getDeal(id);
        assertEq(d.deliveredAt, block.timestamp);
        assertEq(uint8(d.status), uint8(EscrowDeal.Status.Delivered));
    }

    function test_HappyPath_Create_Accept_Deliver_Release_WithdrawSeller() public {
        uint256 id = _createDelivered(arbiter, WINDOW);

        vm.expectEmit(true, true, false, true, address(escrow));
        emit EscrowDeal.Released(id, seller, AMOUNT);
        vm.prank(buyer);
        escrow.release(id);

        assertEq(uint8(_status(id)), uint8(EscrowDeal.Status.Released));
        assertEq(escrow.sellerOwed(id), AMOUNT);
        assertEq(_bal(address(escrow)), AMOUNT); // not yet paid out

        vm.expectEmit(true, true, false, true, address(escrow));
        emit EscrowDeal.SellerWithdrawn(id, payout, AMOUNT);
        vm.prank(stranger); // anyone may trigger the payout; it goes to sellerPayout
        escrow.withdrawSeller(id);

        assertEq(escrow.sellerOwed(id), 0);
        assertEq(_bal(payout), AMOUNT);
        assertEq(_bal(address(escrow)), 0);
    }

    function test_Release_FromAcceptedAllowed() public {
        uint256 id = _createAccepted(arbiter, 0);
        vm.prank(buyer);
        escrow.release(id);
        escrow.withdrawSeller(id);
        assertEq(_bal(payout), AMOUNT);
    }

    // ---------------- refunds ----------------

    function test_Refund_SellerRefundsBuyer_FromAccepted() public {
        uint256 id = _createAccepted(arbiter, WINDOW);
        uint256 before_ = _bal(buyer);
        vm.expectEmit(true, true, false, true, address(escrow));
        emit EscrowDeal.Refunded(id, buyer, AMOUNT);
        vm.prank(seller);
        escrow.refund(id);
        assertEq(uint8(_status(id)), uint8(EscrowDeal.Status.Refunded));
        assertEq(_bal(buyer), before_ + AMOUNT);
        assertEq(_bal(address(escrow)), 0);
    }

    function test_Refund_SellerRefundsBuyer_FromDelivered() public {
        uint256 id = _createDelivered(arbiter, WINDOW);
        uint256 before_ = _bal(buyer);
        vm.prank(seller);
        escrow.refund(id);
        assertEq(_bal(buyer), before_ + AMOUNT);
        assertEq(_bal(address(escrow)), 0);
    }

    function test_CancelUnaccepted_RefundsBuyer() public {
        uint256 id = _create(arbiter, WINDOW);
        uint256 before_ = _bal(buyer);
        vm.expectEmit(true, true, false, true, address(escrow));
        emit EscrowDeal.Refunded(id, buyer, AMOUNT);
        vm.prank(buyer);
        escrow.cancelUnaccepted(id);
        assertEq(uint8(_status(id)), uint8(EscrowDeal.Status.Refunded));
        assertEq(_bal(buyer), before_ + AMOUNT);
        assertEq(_bal(address(escrow)), 0);
    }

    function test_ReclaimExpired_FromFunded() public {
        uint256 id = _create(arbiter, WINDOW);
        uint256 before_ = _bal(buyer);
        vm.warp(deliverBy + 1);
        vm.expectEmit(true, true, false, true, address(escrow));
        emit EscrowDeal.Refunded(id, buyer, AMOUNT);
        vm.prank(buyer);
        escrow.reclaimExpired(id);
        assertEq(_bal(buyer), before_ + AMOUNT);
        assertEq(uint8(_status(id)), uint8(EscrowDeal.Status.Refunded));
    }

    function test_ReclaimExpired_FromAccepted() public {
        uint256 id = _createAccepted(arbiter, WINDOW);
        uint256 before_ = _bal(buyer);
        vm.warp(deliverBy + 1);
        vm.prank(buyer);
        escrow.reclaimExpired(id);
        assertEq(_bal(buyer), before_ + AMOUNT);
        assertEq(_bal(address(escrow)), 0);
    }

    // ---------------- claimAfterReviewWindow ----------------

    function test_ClaimAfterReviewWindow_AfterWindow_CreditsSellerThenWithdraw() public {
        uint256 id = _createDelivered(address(0), WINDOW);
        vm.warp(block.timestamp + WINDOW + 1);
        vm.expectEmit(true, true, false, true, address(escrow));
        emit EscrowDeal.Released(id, seller, AMOUNT);
        vm.prank(seller);
        escrow.claimAfterReviewWindow(id);
        assertEq(uint8(_status(id)), uint8(EscrowDeal.Status.Released));
        assertEq(escrow.sellerOwed(id), AMOUNT);

        escrow.withdrawSeller(id);
        assertEq(_bal(payout), AMOUNT);
        assertEq(_bal(address(escrow)), 0);
    }

    function test_ClaimAfterReviewWindow_BeforeWindow_Reverts() public {
        uint256 id = _createDelivered(address(0), WINDOW);
        skip(WINDOW - 1);
        vm.prank(seller);
        vm.expectRevert(bytes("Review window not passed"));
        escrow.claimAfterReviewWindow(id);
    }

    function test_ClaimAfterReviewWindow_ExactlyAtWindowEnd_Reverts() public {
        uint256 id = _createDelivered(address(0), WINDOW);
        skip(WINDOW);
        vm.prank(seller);
        vm.expectRevert(bytes("Review window not passed"));
        escrow.claimAfterReviewWindow(id);
    }

    // ---------------- disputes ----------------

    function test_RaiseDispute_ByBuyer() public {
        uint256 id = _createDelivered(arbiter, WINDOW);
        vm.expectEmit(true, false, false, false, address(escrow));
        emit EscrowDeal.DisputeRaised(id);
        vm.prank(buyer);
        escrow.raiseDispute(id);
        EscrowDeal.Deal memory d = escrow.getDeal(id);
        assertEq(uint8(d.status), uint8(EscrowDeal.Status.Disputed));
        assertEq(d.disputedAt, block.timestamp);
    }

    function test_RaiseDispute_BySeller() public {
        uint256 id = _createDelivered(arbiter, WINDOW);
        vm.expectEmit(true, false, false, false, address(escrow));
        emit EscrowDeal.DisputeRaised(id);
        vm.prank(seller);
        escrow.raiseDispute(id);
        assertEq(uint8(_status(id)), uint8(EscrowDeal.Status.Disputed));
    }

    function test_RaiseDispute_SellerAfterReviewWindowStillAllowed() public {
        uint256 id = _createDelivered(arbiter, WINDOW);
        skip(WINDOW + 10 days);
        vm.prank(seller);
        escrow.raiseDispute(id);
        assertEq(uint8(_status(id)), uint8(EscrowDeal.Status.Disputed));
    }

    function test_RaiseDispute_BuyerAtExactWindowEndAllowed() public {
        uint256 id = _createDelivered(arbiter, WINDOW);
        skip(WINDOW);
        vm.prank(buyer);
        escrow.raiseDispute(id);
        assertEq(uint8(_status(id)), uint8(EscrowDeal.Status.Disputed));
    }

    function test_RaiseDispute_BuyerAnytimeWhenNoReviewWindow() public {
        uint256 id = _createDelivered(arbiter, 0);
        skip(100 days);
        vm.prank(buyer);
        escrow.raiseDispute(id);
        assertEq(uint8(_status(id)), uint8(EscrowDeal.Status.Disputed));
    }

    function test_ResolveDispute_Split_BothSidesClaim() public {
        uint256 id = _createDisputed();
        uint256 toSeller = 300e6;
        uint256 toBuyer = AMOUNT - toSeller;

        vm.expectEmit(true, false, false, true, address(escrow));
        emit EscrowDeal.DisputeResolved(id, toSeller, toBuyer);
        vm.prank(arbiter);
        escrow.resolveDispute(id, toSeller);

        assertEq(uint8(_status(id)), uint8(EscrowDeal.Status.Resolved));
        assertEq(escrow.claimableOf(id, seller), toSeller);
        assertEq(escrow.claimableOf(id, buyer), toBuyer);
        assertEq(_bal(address(escrow)), AMOUNT);

        uint256 buyerBefore = _bal(buyer);
        vm.prank(buyer);
        escrow.claimResolved(id);
        assertEq(_bal(buyer), buyerBefore + toBuyer);
        assertEq(escrow.claimableOf(id, buyer), 0);

        vm.prank(seller);
        escrow.claimResolved(id);
        assertEq(_bal(payout), toSeller); // paid to sellerPayout, not seller
        assertEq(_bal(seller), 0);
        assertEq(escrow.claimableOf(id, seller), 0);
        assertEq(_bal(address(escrow)), 0);
    }

    function test_ResolveDispute_FullToSeller() public {
        uint256 id = _createDisputed();
        vm.prank(arbiter);
        escrow.resolveDispute(id, AMOUNT);
        assertEq(escrow.claimableOf(id, buyer), 0);
        vm.prank(seller);
        escrow.claimResolved(id);
        assertEq(_bal(payout), AMOUNT);
        // buyer has nothing to claim
        vm.prank(buyer);
        vm.expectRevert(bytes("Nothing to claim"));
        escrow.claimResolved(id);
    }

    function test_ResolveDispute_FullToBuyer() public {
        uint256 id = _createDisputed();
        uint256 before_ = _bal(buyer);
        vm.prank(arbiter);
        escrow.resolveDispute(id, 0);
        vm.prank(buyer);
        escrow.claimResolved(id);
        assertEq(_bal(buyer), before_ + AMOUNT);
        vm.prank(seller);
        vm.expectRevert(bytes("Nothing to claim"));
        escrow.claimResolved(id);
    }

    function test_ClaimResolved_ThirdPartyClaimsForBeneficiary() public {
        uint256 id = _createDisputed();
        vm.prank(arbiter);
        escrow.resolveDispute(id, 400e6);
        vm.prank(stranger);
        escrow.claimResolved(id, seller);
        vm.prank(stranger);
        escrow.claimResolved(id, buyer);
        assertEq(_bal(payout), 400e6);
        assertEq(_bal(stranger), 0);
        assertEq(_bal(address(escrow)), 0);
    }

    function test_RefundStaleDispute_AfterArbiterTimeout() public {
        uint256 id = _createDisputed();
        uint256 before_ = _bal(buyer);
        skip(escrow.ARBITER_TIMEOUT() + 1);
        vm.expectEmit(true, true, false, true, address(escrow));
        emit EscrowDeal.Refunded(id, buyer, AMOUNT);
        vm.prank(buyer);
        escrow.refundStaleDispute(id);
        assertEq(uint8(_status(id)), uint8(EscrowDeal.Status.Refunded));
        assertEq(_bal(buyer), before_ + AMOUNT);
        assertEq(_bal(address(escrow)), 0);
    }

    // ---------------- updatePayout ----------------

    function test_UpdatePayout_ChangesWithdrawDestination() public {
        uint256 id = _createAccepted(arbiter, WINDOW);
        vm.expectEmit(true, false, false, true, address(escrow));
        emit EscrowDeal.PayoutUpdated(id, payout2);
        vm.prank(seller);
        escrow.updatePayout(id, payout2);
        assertEq(escrow.getDeal(id).sellerPayout, payout2);

        vm.prank(buyer);
        escrow.release(id);
        escrow.withdrawSeller(id);
        assertEq(_bal(payout2), AMOUNT);
        assertEq(_bal(payout), 0);
    }

    function test_UpdatePayout_AfterReleaseBeforeWithdraw() public {
        uint256 id = _createAccepted(arbiter, WINDOW);
        vm.prank(buyer);
        escrow.release(id);
        vm.prank(seller);
        escrow.updatePayout(id, payout2);
        escrow.withdrawSeller(id);
        assertEq(_bal(payout2), AMOUNT);
    }

    function test_UpdatePayout_AfterResolutionRedirectsSellerClaim() public {
        uint256 id = _createDisputed();
        vm.prank(arbiter);
        escrow.resolveDispute(id, 250e6);
        vm.prank(seller);
        escrow.updatePayout(id, payout2);
        escrow.claimResolved(id, seller);
        assertEq(_bal(payout2), 250e6);
        assertEq(_bal(payout), 0);
    }

    // ---------------- views ----------------

    function test_DealsOf_TracksMultipleDeals() public {
        _create(arbiter, WINDOW);
        _create(address(0), WINDOW);
        uint256[] memory ids = escrow.dealsOf(seller);
        assertEq(ids.length, 2);
        assertEq(ids[0], 0);
        assertEq(ids[1], 1);
        assertEq(escrow.dealCount(), 2);
    }
}
