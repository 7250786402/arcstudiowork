// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CrowdfundTestBase} from "./Crowdfund.Base.t.sol";
import {Crowdfund} from "../Crowdfund.sol";
import {MockERC20} from "../test-helpers/MockERC20.sol";

contract CrowdfundHandler is Test {
    Crowdfund public cf;
    MockERC20 public usdc;
    address[] public actors;
    address public creator;

    uint256 public ghostWithdrawnPaid;

    constructor(Crowdfund _cf, MockERC20 _usdc, address[] memory _actors, address _creator) {
        cf = _cf;
        usdc = _usdc;
        actors = _actors;
        creator = _creator;
    }

    function _actor(uint256 seed) internal view returns (address) {
        return actors[seed % actors.length];
    }

    function _id(uint256 seed) internal view returns (uint256) {
        return seed % cf.campaignCount();
    }

    function create(uint256 goal, uint256 duration) external {
        if (cf.campaignCount() >= 8) return;
        goal = bound(goal, 1, 5_000e6);
        duration = bound(duration, 1 hours, 30 days);
        vm.prank(creator);
        cf.createCampaign("T", "D", goal, duration, address(uint160(0x20000)));
    }

    function pledge(uint256 idSeed, uint256 actorSeed, uint256 amount) external {
        if (cf.campaignCount() == 0) return;
        uint256 id = _id(idSeed);
        address a = _actor(actorSeed);
        amount = bound(amount, 1, 2_000e6);
        vm.prank(a);
        try cf.pledge(id, amount) {} catch {}
    }

    function refund(uint256 idSeed, uint256 actorSeed) external {
        if (cf.campaignCount() == 0) return;
        vm.prank(_actor(actorSeed));
        try cf.refund(_id(idSeed)) {} catch {}
    }

    function withdraw(uint256 idSeed, uint256 callerSeed) external {
        if (cf.campaignCount() == 0) return;
        vm.prank(_actor(callerSeed));
        try cf.withdrawFunds(_id(idSeed)) {} catch {}
    }

    function cancel(uint256 idSeed) external {
        if (cf.campaignCount() == 0) return;
        vm.prank(creator);
        try cf.cancelCampaign(_id(idSeed)) {} catch {}
    }

    function warp(uint256 dt) external {
        dt = bound(dt, 0, 10 days);
        vm.warp(block.timestamp + dt);
    }
}

contract CrowdfundInvariantTest is CrowdfundTestBase {
    CrowdfundHandler internal handler;
    address[] internal actors;

    function setUp() public override {
        super.setUp();
        actors.push(alice);
        actors.push(bob);
        actors.push(carol);
        handler = new CrowdfundHandler(cf, usdc, actors, creator);
        targetContract(address(handler));
    }

    /// Contract USDC balance == Σ (raised - refunded) over campaigns not yet withdrawn.
    function invariant_BalanceEqualsOutstandingPledges() public view {
        uint256 n = cf.campaignCount();
        uint256 expected;
        for (uint256 i = 0; i < n; i++) {
            Crowdfund.Campaign memory c = cf.getCampaign(i);
            if (!c.withdrawn) expected += c.raised - c.refunded;
        }
        assertEq(usdc.balanceOf(address(cf)), expected);
    }

    /// Per-campaign: refunded <= raised, and outstanding pledges of all actors == raised - refunded.
    function invariant_PledgesMatchRaisedMinusRefunded() public view {
        uint256 n = cf.campaignCount();
        for (uint256 i = 0; i < n; i++) {
            Crowdfund.Campaign memory c = cf.getCampaign(i);
            assertLe(c.refunded, c.raised);
            uint256 sum;
            for (uint256 j = 0; j < actors.length; j++) {
                sum += cf.pledgeOf(i, actors[j]);
            }
            assertEq(sum, c.raised - c.refunded);
        }
    }

    /// A campaign can never be both withdrawn and cancelled, and withdrawn campaigns have met goal.
    function invariant_WithdrawnCampaignsMetGoalAndNotCancelled() public view {
        uint256 n = cf.campaignCount();
        for (uint256 i = 0; i < n; i++) {
            Crowdfund.Campaign memory c = cf.getCampaign(i);
            if (c.withdrawn) {
                assertFalse(c.cancelled);
                assertGe(c.raised, c.goal);
                assertEq(c.refunded, 0);
            }
        }
    }
}
