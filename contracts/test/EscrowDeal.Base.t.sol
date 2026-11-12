// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {EscrowDeal} from "../EscrowDeal.sol";
import {MockERC20} from "../test-helpers/MockERC20.sol";

abstract contract EscrowDealTestBase is Test {
    address internal constant USDC = 0x3600000000000000000000000000000000000000;

    EscrowDeal internal escrow;
    MockERC20 internal usdc;

    address internal buyer = makeAddr("buyer");
    address internal seller = makeAddr("seller");
    address internal payout = makeAddr("payout");
    address internal payout2 = makeAddr("payout2");
    address internal arbiter = makeAddr("arbiter");
    address internal stranger = makeAddr("stranger");

    uint256 internal constant AMOUNT = 1_000e6;
    uint256 internal constant WINDOW = 3 days;
    uint256 internal constant START = 1_700_000_000;

    uint256 internal deliverBy;

    function setUp() public virtual {
        vm.warp(START);
        MockERC20 mock = new MockERC20();
        vm.etch(USDC, address(mock).code);
        usdc = MockERC20(USDC);

        usdc.mint(buyer, 100_000e6);
        escrow = new EscrowDeal();
        vm.prank(buyer);
        usdc.approve(address(escrow), type(uint256).max);

        deliverBy = block.timestamp + 7 days;
    }

    // ---- helpers -------------------------------------------------------

    function _create(address arb, uint256 window) internal returns (uint256 id) {
        vm.prank(buyer);
        id = escrow.createDeal(seller, AMOUNT, "title", "terms", deliverBy, arb, window);
    }

    function _createAccepted(address arb, uint256 window) internal returns (uint256 id) {
        id = _create(arb, window);
        vm.prank(seller);
        escrow.acceptDeal(id, payout);
    }

    function _createDelivered(address arb, uint256 window) internal returns (uint256 id) {
        id = _createAccepted(arb, window);
        vm.prank(seller);
        escrow.markDelivered(id);
    }

    function _createDisputed() internal returns (uint256 id) {
        id = _createDelivered(arbiter, WINDOW);
        vm.prank(buyer);
        escrow.raiseDispute(id);
    }

    function _status(uint256 id) internal view returns (EscrowDeal.Status) {
        return escrow.getDeal(id).status;
    }

    function _bal(address a) internal view returns (uint256) {
        return usdc.balanceOf(a);
    }
}
