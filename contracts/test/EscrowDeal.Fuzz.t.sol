// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {EscrowDealTestBase} from "./EscrowDeal.Base.t.sol";
import {EscrowDeal} from "../EscrowDeal.sol";

contract EscrowDealFuzzTest is EscrowDealTestBase {
    function _disputed(uint256 amount) internal returns (uint256 id) {
        usdc.mint(buyer, amount);
        vm.startPrank(buyer);
        id = escrow.createDeal(seller, amount, "t", "x", deliverBy, arbiter, WINDOW);
        vm.stopPrank();
        vm.startPrank(seller);
        escrow.acceptDeal(id, payout);
        escrow.markDelivered(id);
        vm.stopPrank();
        vm.prank(buyer);
        escrow.raiseDispute(id);
    }

    function testFuzz_DisputeSplit_PayoutsSumToDealAmount(uint256 amount, uint256 sellerAmount) public {
        amount = bound(amount, 1, 1e24);
        sellerAmount = bound(sellerAmount, 0, amount);
        uint256 id = _disputed(amount);

        uint256 buyerBefore = _bal(buyer);
        uint256 payoutBefore = _bal(payout);
        uint256 escrowBefore = _bal(address(escrow));

        vm.expectEmit(true, false, false, true, address(escrow));
        emit EscrowDeal.DisputeResolved(id, sellerAmount, amount - sellerAmount);
        vm.prank(arbiter);
        escrow.resolveDispute(id, sellerAmount);

        assertEq(escrow.claimableOf(id, seller) + escrow.claimableOf(id, buyer), amount);

        if (sellerAmount > 0) escrow.claimResolved(id, seller);
        if (sellerAmount < amount) escrow.claimResolved(id, buyer);

        uint256 buyerGot = _bal(buyer) - buyerBefore;
        uint256 sellerGot = _bal(payout) - payoutBefore;
        assertEq(sellerGot, sellerAmount);
        assertEq(buyerGot, amount - sellerAmount);
        assertEq(buyerGot + sellerGot, amount);
        assertEq(_bal(address(escrow)), escrowBefore - amount);
    }

    function testFuzz_ResolveAboveAmountReverts(uint256 amount, uint256 over) public {
        amount = bound(amount, 1, 1e24);
        over = bound(over, 1, type(uint128).max);
        uint256 id = _disputed(amount);
        vm.prank(arbiter);
        vm.expectRevert(bytes("Exceeds escrow amount"));
        escrow.resolveDispute(id, amount + over);
    }

    function testFuzz_ReleaseWithdrawPaysExactAmount(uint256 amount) public {
        amount = bound(amount, 1, 1e24);
        usdc.mint(buyer, amount);
        vm.prank(buyer);
        uint256 id = escrow.createDeal(seller, amount, "t", "x", deliverBy, arbiter, 0);
        vm.prank(seller);
        escrow.acceptDeal(id, payout);
        vm.prank(buyer);
        escrow.release(id);
        escrow.withdrawSeller(id);
        assertEq(_bal(payout), amount);
        assertEq(_bal(address(escrow)), 0);
    }

    function testFuzz_ClaimAfterWindow_OnlyStrictlyAfter(uint256 window, uint256 elapsed) public {
        window = bound(window, 1 days, 30 days);
        elapsed = bound(elapsed, 0, 60 days);
        vm.prank(buyer);
        uint256 id = escrow.createDeal(seller, AMOUNT, "t", "x", block.timestamp + 90 days, address(0), window);
        vm.startPrank(seller);
        escrow.acceptDeal(id, payout);
        escrow.markDelivered(id);
        skip(elapsed);
        if (elapsed > window) {
            escrow.claimAfterReviewWindow(id);
            assertEq(escrow.sellerOwed(id), AMOUNT);
        } else {
            vm.expectRevert(bytes("Review window not passed"));
            escrow.claimAfterReviewWindow(id);
        }
        vm.stopPrank();
    }

    function testFuzz_StaleDisputeRefund_OnlyAfterTimeout(uint256 elapsed) public {
        elapsed = bound(elapsed, 0, 60 days);
        uint256 id = _disputed(AMOUNT);
        skip(elapsed);
        uint256 timeout = escrow.ARBITER_TIMEOUT();
        vm.startPrank(buyer);
        if (elapsed > timeout) {
            escrow.refundStaleDispute(id);
            assertEq(uint8(_status(id)), uint8(EscrowDeal.Status.Refunded));
        } else {
            vm.expectRevert(bytes("Arbiter timeout not passed"));
            escrow.refundStaleDispute(id);
        }
        vm.stopPrank();
    }
}
