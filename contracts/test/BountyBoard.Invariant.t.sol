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
    /// Number of bounties created through the handler (the only creator), so we never copy getBounties().
    uint256 public count;
    /// Incrementally-synced view of on-chain state (read from the contract for each touched bounty only).
    uint256 public openSum;
    bool public claimerMismatch;
    mapping(uint256 => uint256) internal _openContribution;

    function _sync(uint256 id) internal {
        BountyBoard.Bounty memory b = bb.getBounty(id);
        uint256 now_ = b.status == BountyBoard.BountyStatus.Open ? b.reward : 0;
        openSum = openSum - _openContribution[id] + now_;
        _openContribution[id] = now_;
        if ((b.claimer != address(0)) != (b.status == BountyBoard.BountyStatus.Claimed)) claimerMismatch = true;
    }

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
        uint256 n = count;
        return n == 0 ? 0 : seed % n;
    }

    function create(uint256 actorSeed, uint256 reward, uint256 dlOffset, uint8 bType) external {
        reward = bound(reward, 1, 10_000e6);
        dlOffset = bound(dlOffset, 1, 365 days);
        uint256 dl = block.timestamp + dlOffset;
        bType = uint8(bound(bType, 0, 2));
        vm.prank(_actor(actorSeed));
        try bb.createBounty("t", "d", reward, "g", dl, "c", bType, 1) {
            ghostDeposited += reward;
            count++;
            _sync(count - 1);
        } catch {}
    }

    bool public creatorSubmitted;

    function submit(uint256 actorSeed, uint256 idSeed) external {
        if (count == 0) return;
        uint256 id = _id(idSeed);
        address who = _actor(actorSeed);
        address c = bb.getBounty(id).creator;
        vm.prank(who);
        try bb.submitWork(id, "n") {
            if (who == c) creatorSubmitted = true;
        } catch {}
    }

    bool public indexBroken;

    function withdraw(uint256 actorSeed, uint256 idSeed) external {
        uint256 id = _id(idSeed);
        address who = _actor(actorSeed);
        if (count == 0) return;
        BountyBoard.Submission[] memory before_ = bb.getSubmissions(id);
        vm.prank(who);
        try bb.withdrawSubmission(id) {
            BountyBoard.Submission[] memory after_ = bb.getSubmissions(id);
            if (after_.length + 1 != before_.length) indexBroken = true;
            for (uint256 i = 0; i < before_.length; i++) {
                uint256 count;
                for (uint256 j = 0; j < after_.length; j++) {
                    if (after_[j].submitter == before_[i].submitter) count++;
                }
                if (count != (before_[i].submitter == who ? 0 : 1)) indexBroken = true;
            }
        } catch {}
    }

    function approve(uint256 idSeed, uint256 claimerSeed) external {
        uint256 id = _id(idSeed);
        if (count == 0) return;
        BountyBoard.Bounty memory b = bb.getBounty(id);
        vm.prank(b.creator);
        try bb.approveClaimer(id, _actor(claimerSeed)) {
            ghostPaidOut += b.reward;
            _sync(id);
        } catch {}
    }

    function cancel(uint256 idSeed) external {
        uint256 id = _id(idSeed);
        if (count == 0) return;
        BountyBoard.Bounty memory b = bb.getBounty(id);
        vm.prank(b.creator);
        try bb.cancelBounty(id) {
            ghostRefunded += b.reward;
            _sync(id);
        } catch {}
    }

    function expire(uint256 idSeed) external {
        uint256 id = _id(idSeed);
        if (count == 0) return;
        BountyBoard.Bounty memory b = bb.getBounty(id);
        vm.prank(b.creator);
        try bb.claimExpiredBounty(id) {
            ghostRefunded += b.reward;
            _sync(id);
        } catch {}
    }

    function emergencyRefund(uint256 idSeed) external {
        uint256 id = _id(idSeed);
        if (count == 0) return;
        BountyBoard.Bounty memory b = bb.getBounty(id);
        vm.startPrank(owner);
        bb.setEmergencyMode(true);
        try bb.emergencyRefund(id) {
            ghostRefunded += b.reward;
            _sync(id);
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
        assertEq(_bal(address(bb)), handler.openSum());
    }

    /// Money conservation: deposited == paid out + refunded + still escrowed.
    function invariant_DepositsEqualPayoutsPlusRefundsPlusEscrow() public view {
        assertEq(handler.ghostDeposited(), handler.ghostPaidOut() + handler.ghostRefunded() + _bal(address(bb)));
    }

    /// Claimed bounties always have a claimer; others never do.
    function invariant_ClaimerSetIffClaimed() public view {
        assertFalse(handler.claimerMismatch());
    }

    /// bountiesCreated summed over actors equals the number of bounties.
    function invariant_CreatedCountMatchesBountyCount() public view {
        uint256 total = bb.bountiesCreated(creator) + bb.bountiesCreated(alice) + bb.bountiesCreated(bob)
            + bb.bountiesCreated(carol);
        assertEq(total, handler.count());
    }

    /// O(1) withdraw index map: every successful withdraw removed exactly the caller and kept all others.
    function invariant_WithdrawIndexMapConsistent() public view {
        assertFalse(handler.indexBroken());
    }

    /// The creator never manages to submit to their own bounty.
    function invariant_CreatorNeverSubmits() public view {
        assertFalse(handler.creatorSubmitted());
    }
}
