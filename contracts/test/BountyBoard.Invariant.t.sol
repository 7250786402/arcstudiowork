// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {BountyBoardTestBase} from "./BountyBoard.Base.t.sol";
import {BountyBoard} from "../BountyBoard.sol";
import {MockERC20} from "../test-helpers/MockERC20.sol";

contract BountyBoardHandler is Test {
    BountyBoard public bb;
    MockERC20 public usdc;
    address public owner;
    address[] public actors;

    uint256 public ghostPaidOut; // approveClaimer payouts
    uint256 public ghostRefunded; // cancels/expiries/emergency refunds
    uint256 public ghostDeposited;

    constructor(BountyBoard _bb, MockERC20 _usdc, address _owner, address[] memory _actors) {
        bb = _bb;
        usdc = _usdc;
        owner = _owner;
        actors = _actors;
    }

    function _actor(uint256 seed) internal view returns (address) {
        return actors[seed % actors.length];
    }

    function _id(uint256 seed) internal view returns (uint256) {
        uint256 n = bb.getBounties().length;
        return n == 0 ? 0 : seed % n;
    }

    function create(uint256 actorSeed, uint256 reward, uint256 dlOffset, uint8 bType) external {
        reward = bound(reward, 1, 10_000e6);
        dlOffset = bound(dlOffset, 0, 30 days);
        uint256 dl = dlOffset == 0 ? 0 : block.timestamp + dlOffset;
        bType = uint8(bound(bType, 0, 2));
        vm.prank(_actor(actorSeed));
        try bb.createBounty("t", "d", reward, "g", dl, "c", bType, 1) {
            ghostDeposited += reward;
        } catch {}
    }

    function submit(uint256 actorSeed, uint256 idSeed) external {
        vm.prank(_actor(actorSeed));
        try bb.submitWork(_id(idSeed), "n") {} catch {}
    }

    function withdraw(uint256 actorSeed, uint256 idSeed) external {
        vm.prank(_actor(actorSeed));
        try bb.withdrawSubmission(_id(idSeed)) {} catch {}
    }

    function approve(uint256 idSeed, uint256 claimerSeed) external {
        uint256 id = _id(idSeed);
        if (bb.getBounties().length == 0) return;
        BountyBoard.Bounty memory b = bb.getBounty(id);
        vm.prank(b.creator);
        try bb.approveClaimer(id, _actor(claimerSeed)) {
            ghostPaidOut += b.reward;
        } catch {}
    }

    function cancel(uint256 idSeed) external {
        uint256 id = _id(idSeed);
        if (bb.getBounties().length == 0) return;
        BountyBoard.Bounty memory b = bb.getBounty(id);
        vm.prank(b.creator);
        try bb.cancelBounty(id) {
            ghostRefunded += b.reward;
        } catch {}
    }

    function expire(uint256 idSeed) external {
        uint256 id = _id(idSeed);
        if (bb.getBounties().length == 0) return;
        BountyBoard.Bounty memory b = bb.getBounty(id);
        vm.prank(b.creator);
        try bb.claimExpiredBounty(id) {
            ghostRefunded += b.reward;
        } catch {}
    }

    function emergencyRefund(uint256 idSeed) external {
        uint256 id = _id(idSeed);
        if (bb.getBounties().length == 0) return;
        BountyBoard.Bounty memory b = bb.getBounty(id);
        vm.startPrank(owner);
        bb.setEmergencyMode(true);
        try bb.emergencyRefund(id) {
            ghostRefunded += b.reward;
        } catch {}
        bb.setEmergencyMode(false);
        vm.stopPrank();
    }

    function tip(uint256 actorSeed, uint256 idSeed, uint256 amount) external {
        amount = bound(amount, 1, 1_000e6);
        vm.prank(_actor(actorSeed));
        try bb.tipWinner(_id(idSeed), amount) {} catch {}
    }

    function warp(uint256 dt) external {
        skip(bound(dt, 0, 10 days));
    }
}

contract BountyBoardInvariantTest is BountyBoardTestBase {
    BountyBoardHandler internal handler;

    function setUp() public override {
        super.setUp();
        address[] memory actors = new address[](4);
        actors[0] = creator;
        actors[1] = alice;
        actors[2] = bob;
        actors[3] = carol;
        handler = new BountyBoardHandler(bb, usdc, owner, actors);
        targetContract(address(handler));
    }

    /// Contract USDC balance == sum of rewards of Open bounties.
    function invariant_BalanceEqualsSumOfOpenRewards() public view {
        BountyBoard.Bounty[] memory all = bb.getBounties();
        uint256 sum;
        for (uint256 i = 0; i < all.length; i++) {
            if (all[i].status == BountyBoard.BountyStatus.Open) sum += all[i].reward;
        }
        assertEq(_bal(address(bb)), sum);
    }

    /// Money conservation: deposited == paid out + refunded + still escrowed.
    function invariant_DepositsEqualPayoutsPlusRefundsPlusEscrow() public view {
        assertEq(handler.ghostDeposited(), handler.ghostPaidOut() + handler.ghostRefunded() + _bal(address(bb)));
    }

    /// Claimed bounties always have a claimer; others never do.
    function invariant_ClaimerSetIffClaimed() public view {
        BountyBoard.Bounty[] memory all = bb.getBounties();
        for (uint256 i = 0; i < all.length; i++) {
            bool claimed = all[i].status == BountyBoard.BountyStatus.Claimed;
            assertEq(all[i].claimer != address(0), claimed);
        }
    }

    /// bountiesCreated summed over actors equals the number of bounties.
    function invariant_CreatedCountMatchesBountyCount() public view {
        uint256 total = bb.bountiesCreated(creator) + bb.bountiesCreated(alice) + bb.bountiesCreated(bob)
            + bb.bountiesCreated(carol);
        assertEq(total, bb.getBounties().length);
    }
}
