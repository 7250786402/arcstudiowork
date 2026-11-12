// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {EscrowDeal} from "../EscrowDeal.sol";
import {MockERC20} from "../test-helpers/MockERC20.sol";

/// @dev Drives bounded, role-correct calls against the escrow.
contract EscrowDealHandler is Test {
    EscrowDeal public escrow;
    MockERC20 public usdc;

    address[2] internal buyers = [address(0xB1), address(0xB2)];
    address[2] internal sellers = [address(0x5E11E7), address(0x5E11E8)];
    address[2] internal payouts = [address(0x70001), address(0x70002)];
    address internal constant ARB = address(0xA4B1);

    constructor(EscrowDeal _escrow, MockERC20 _usdc) {
        escrow = _escrow;
        usdc = _usdc;
        for (uint256 i; i < 2; i++) {
            vm.prank(buyers[i]);
            usdc.approve(address(escrow), type(uint256).max);
        }
    }

    function _id(uint256 seed) internal view returns (bool ok, uint256 id) {
        uint256 n = escrow.dealCount();
        if (n == 0) return (false, 0);
        return (true, seed % n);
    }

    function create(uint256 amountSeed, uint256 who, bool withArbiter, uint256 windowSeed) external {
        uint256 amount = bound(amountSeed, 1, 1e12);
        address b = buyers[who % 2];
        address s = sellers[(who / 2) % 2];
        uint256 window = windowSeed % 3 == 0 ? 0 : bound(windowSeed, 1 days, 30 days);
        if (!withArbiter && window == 0) window = 1 days;
        usdc.mint(b, amount);
        vm.prank(b);
        escrow.createDeal(s, amount, "t", "x", block.timestamp + bound(windowSeed, 1 days, 20 days), withArbiter ? ARB : address(0), window);
    }

    function accept(uint256 seed) external {
        (bool ok, uint256 id) = _id(seed);
        if (!ok) return;
        vm.prank(escrow.getDeal(id).seller);
        escrow.acceptDeal(id, payouts[seed % 2]);
    }

    function deliver(uint256 seed) external {
        (bool ok, uint256 id) = _id(seed);
        if (!ok) return;
        vm.prank(escrow.getDeal(id).seller);
        escrow.markDelivered(id);
    }

    function release(uint256 seed) external {
        (bool ok, uint256 id) = _id(seed);
        if (!ok) return;
        vm.prank(escrow.getDeal(id).buyer);
        escrow.release(id);
    }

    function withdraw(uint256 seed) external {
        (bool ok, uint256 id) = _id(seed);
        if (!ok) return;
        escrow.withdrawSeller(id);
    }

    function sellerRefund(uint256 seed) external {
        (bool ok, uint256 id) = _id(seed);
        if (!ok) return;
        vm.prank(escrow.getDeal(id).seller);
        escrow.refund(id);
    }

    function cancel(uint256 seed) external {
        (bool ok, uint256 id) = _id(seed);
        if (!ok) return;
        vm.prank(escrow.getDeal(id).buyer);
        escrow.cancelUnaccepted(id);
    }

    function reclaim(uint256 seed) external {
        (bool ok, uint256 id) = _id(seed);
        if (!ok) return;
        vm.prank(escrow.getDeal(id).buyer);
        escrow.reclaimExpired(id);
    }

    function claimAfter(uint256 seed) external {
        (bool ok, uint256 id) = _id(seed);
        if (!ok) return;
        vm.prank(escrow.getDeal(id).seller);
        escrow.claimAfterReviewWindow(id);
    }

    function raise(uint256 seed, bool bySeller) external {
        (bool ok, uint256 id) = _id(seed);
        if (!ok) return;
        EscrowDeal.Deal memory d = escrow.getDeal(id);
        vm.prank(bySeller ? d.seller : d.buyer);
        escrow.raiseDispute(id);
    }

    function resolve(uint256 seed, uint256 sellerSeed) external {
        (bool ok, uint256 id) = _id(seed);
        if (!ok) return;
        uint256 amt = bound(sellerSeed, 0, escrow.getDeal(id).amount);
        vm.prank(ARB);
        escrow.resolveDispute(id, amt);
    }

    function claimResolved(uint256 seed, bool sellerSide) external {
        (bool ok, uint256 id) = _id(seed);
        if (!ok) return;
        EscrowDeal.Deal memory d = escrow.getDeal(id);
        escrow.claimResolved(id, sellerSide ? d.seller : d.buyer);
    }

    function stale(uint256 seed) external {
        (bool ok, uint256 id) = _id(seed);
        if (!ok) return;
        vm.prank(escrow.getDeal(id).buyer);
        escrow.refundStaleDispute(id);
    }

    function updatePayout(uint256 seed) external {
        (bool ok, uint256 id) = _id(seed);
        if (!ok) return;
        vm.prank(escrow.getDeal(id).seller);
        escrow.updatePayout(id, payouts[(seed / 7) % 2]);
    }

    function warp(uint256 secs) external {
        skip(bound(secs, 0, 16 days));
    }
}

contract EscrowDealInvariantTest is Test {
    address internal constant USDC = 0x3600000000000000000000000000000000000000;

    EscrowDeal internal escrow;
    MockERC20 internal usdc;
    EscrowDealHandler internal handler;

    function setUp() public {
        vm.warp(1_700_000_000);
        MockERC20 mock = new MockERC20();
        vm.etch(USDC, address(mock).code);
        usdc = MockERC20(USDC);
        escrow = new EscrowDeal();
        handler = new EscrowDealHandler(escrow, usdc);
        targetContract(address(handler));
    }

    /// @dev Sum of everything the escrow still owes to someone.
    function _unsettled() internal view returns (uint256 total) {
        uint256 n = escrow.dealCount();
        for (uint256 i; i < n; i++) {
            EscrowDeal.Deal memory d = escrow.getDeal(i);
            EscrowDeal.Status s = d.status;
            if (
                s == EscrowDeal.Status.Funded || s == EscrowDeal.Status.Accepted || s == EscrowDeal.Status.Delivered
                    || s == EscrowDeal.Status.Disputed
            ) {
                total += d.amount;
            } else if (s == EscrowDeal.Status.Released) {
                total += escrow.sellerOwed(i);
            } else if (s == EscrowDeal.Status.Resolved) {
                total += escrow.claimableOf(i, d.seller) + escrow.claimableOf(i, d.buyer);
            }
        }
    }

    function invariant_BalanceCoversUnsettledDeals() public view {
        assertGe(usdc.balanceOf(address(escrow)), _unsettled());
    }

    /// @dev Stronger: nothing else funds the escrow, so it should match exactly (no stuck dust).
    function invariant_BalanceEqualsUnsettledDeals() public view {
        assertEq(usdc.balanceOf(address(escrow)), _unsettled());
    }

    function invariant_ResolvedSplitNeverExceedsAmount() public view {
        uint256 n = escrow.dealCount();
        for (uint256 i; i < n; i++) {
            EscrowDeal.Deal memory d = escrow.getDeal(i);
            if (d.status == EscrowDeal.Status.Resolved) {
                assertLe(escrow.claimableOf(i, d.seller) + escrow.claimableOf(i, d.buyer), d.amount);
            }
        }
    }
}
